# frozen_string_literal: true

require "pathname"

module RailVerdict
  module Check
    Outcome = Struct.new(:result, :context, :configuration, :findings, keyword_init: true)

    REGISTRY = {
      "rubocop" => RailVerdict::Analyzers::RuboCop,
      "minitest" => RailVerdict::Analyzers::Minitest,
      "rspec" => RailVerdict::Analyzers::RSpec,
      "simplecov" => RailVerdict::Analyzers::SimpleCov,
      "bundler_audit" => RailVerdict::Analyzers::BundlerAudit
    }.freeze

    def self.registry
      REGISTRY
    end

    module_function

    def execute(repository_root:, config_path:, runner: ProcessRunner, rubocop_command_resolver: nil, analyzer_timeout_seconds: 30.0, interrupted: nil, baseline_path_override: nil, clock: Time.now.utc)
      root = File.realpath(repository_root)
      resolved_config = resolve_config_path(root, config_path)
      configuration = Configuration.load(resolved_config)
      return interrupted_outcome if interrupted&.call

      probes = probe_enabled_analyzers(root, configuration, runner: runner, rubocop_command_resolver: rubocop_command_resolver, timeout_seconds: analyzer_timeout_seconds)

      analyzer_versions = probes.transform_values(&:version)
      context = RunContext.build(
        repository_root: root,
        configuration: configuration,
        analyzer_versions: analyzer_versions,
        revision_resolver: revision_resolver(root, runner)
      )
      return interrupted_outcome(context: context, configuration: configuration) if interrupted&.call

      analyzer_results = []
      findings = []
      configuration.analyzers.each do |name, selection|
        next unless selection.fetch("enabled")

        adapter_class = REGISTRY[name]
        unless adapter_class
          analyzer_results << AnalyzerResult.new(
            analyzer: name,
            invocation: { "executable" => name, "argv" => [] },
            execution_status: "unavailable",
            finding_ids: [],
            failure: { "code" => "unavailable", "message" => "analyzer #{name} is not implemented in this build" }
          )
          next
        end

        adapter = build_adapter(name, rubocop_command_resolver)
        probe = probes[name]
        analyzer_result, analyzer_findings = adapter.run(
          root,
          runner: runner,
          probe_result: probe,
          timeout_seconds: analyzer_timeout_seconds
        )
        analyzer_results << analyzer_result
        findings.concat(analyzer_findings)
      end
      return interrupted_outcome(context: context, configuration: configuration, analyzer_results: analyzer_results, findings: findings) if interrupted&.call

      baseline = nil
      baseline_meta = nil
      comparison = nil
      classified_findings = findings
      begin
        resolved_baseline_path = Baseline.resolve_path(repository_root: root, configuration: configuration, output_override: baseline_path_override)
        if File.file?(resolved_baseline_path)
          loaded = Baseline.read(resolved_baseline_path)
          baseline = loaded
          baseline_meta = { "loaded" => true, "path" => resolved_baseline_path, "schema_version" => Baseline::SCHEMA_VERSION, "fingerprint_version" => Fingerprint::VERSION, "compatible" => true }
          cmp = Comparison.classify(findings: findings, baseline: loaded)
          comparison = { "counts" => cmp.counts, "introduced" => cmp.introduced.map(&:fingerprint).sort, "existing" => cmp.existing.map(&:fingerprint).sort, "resolved" => cmp.resolved.map { |entry| entry.fetch("fingerprint") }.sort, "changed" => cmp.changed.map(&:fingerprint).sort, "moved" => cmp.moved.map(&:fingerprint).sort, "waived" => cmp.counts.fetch("waived", 0) == 0 ? [] : cmp.classified_findings.select { |item| item.state == "waived" }.map(&:fingerprint).sort }
          classified_findings = cmp.classified_findings
        end
      rescue Baseline::IncompatibleError => error
        resolved_baseline_path ||= Baseline.resolve_path(repository_root: root, configuration: configuration, output_override: baseline_path_override)
        incomplete = Verification::Policy.incomplete_result(
          analyzer_results: analyzer_results,
          findings: findings,
          operational_failures: [{ "code" => "failed", "message" => error.message }],
          code: "baseline_incompatible",
          message: error.message
        )
        enriched = GateResult.new(completion_status: incomplete.completion_status, gate: incomplete.gate, policy_status: incomplete.policy_status, findings: incomplete.findings, analyzer_results: incomplete.analyzer_results, operational_failures: incomplete.operational_failures, decision_reasons: incomplete.decision_reasons, baseline: { "loaded" => false, "path" => resolved_baseline_path, "compatible" => false }, comparison: nil)
        return Outcome.new(result: enriched, context: context, configuration: configuration, findings: findings.freeze)
      end

      result = Verification::Policy.evaluate(
        configuration: configuration,
        analyzer_results: analyzer_results,
        findings: classified_findings,
        comparison: comparison,
        baseline_meta: baseline_meta
      )
      if baseline_meta || comparison
        result = GateResult.new(
          completion_status: result.completion_status,
          gate: result.gate,
          policy_status: result.policy_status,
          findings: result.findings,
          analyzer_results: result.analyzer_results,
          operational_failures: result.operational_failures,
          decision_reasons: result.decision_reasons,
          baseline: baseline_meta,
          comparison: comparison
        )
      end
      Outcome.new(result: result, context: context, configuration: configuration, findings: classified_findings.freeze)
    rescue ConfigurationError => error
      Outcome.new(
        result: Verification::Policy.incomplete_result(
          operational_failures: [{ "code" => "configuration", "message" => canonical_error_message(error, root) }],
          code: "configuration",
          message: "Configuration is invalid; no analyzer evidence was evaluated."
        ),
        context: nil,
        configuration: nil,
        findings: [].freeze
      )
    rescue ProcessRunner::DirectoryError, RailVerdict::Error => error
      Outcome.new(
        result: Verification::Policy.incomplete_result(
          operational_failures: [{ "code" => "failed", "message" => error.message }],
          code: "execution_failed",
          message: "Verification could not complete."
        ),
        context: nil,
        configuration: nil,
        findings: [].freeze
      )
    end

    def canonical_error_message(error, root)
      return error.message unless error.source_path

      relative = Pathname.new(error.source_path).relative_path_from(Pathname.new(root)).to_s
      error.message.gsub(error.source_path, relative)
    end
    private_class_method :canonical_error_message

    def resolve_config_path(root, config_path)
      path = config_path.to_s
      Pathname.new(path).absolute? ? path : File.expand_path(path, root)
    end
    private_class_method :resolve_config_path

    def revision_resolver(root, runner)
      lambda do |_resolved_root|
        result = runner.run("git", ["rev-parse", "HEAD"], chdir: root, timeout_seconds: 5.0)
        next nil unless result.status == :exited && result.exit_code == 0

        revision = result.stdout.to_s.strip
        revision.match?(/\A[0-9a-f]{7,64}\z/) ? revision : nil
      end
    end
    private_class_method :revision_resolver

    def interrupted_outcome(context: nil, configuration: nil, analyzer_results: [], findings: [])
      Outcome.new(
        result: Verification::Policy.interrupted_result(analyzer_results: analyzer_results, findings: findings),
        context: context,
        configuration: configuration,
        findings: findings.freeze
      )
    end
    private_class_method :interrupted_outcome

    def build_adapter(name, rubocop_command_resolver)
      case name
      when "rubocop"
        RailVerdict::Analyzers::RuboCop.new(command_resolver: rubocop_command_resolver)
      when "minitest"
        RailVerdict::Analyzers::Minitest.new
      when "rspec"
        RailVerdict::Analyzers::RSpec.new
      when "simplecov"
        RailVerdict::Analyzers::SimpleCov.new
      when "bundler_audit"
        RailVerdict::Analyzers::BundlerAudit.new
      end
    end
    private_class_method :build_adapter

    def probe_enabled_analyzers(root, configuration, runner:, rubocop_command_resolver:, timeout_seconds:)
      probes = {}
      configuration.analyzers.each do |name, selection|
        next unless selection.fetch("enabled")

        adapter_class = REGISTRY[name]
        next unless adapter_class

        adapter = build_adapter(name, rubocop_command_resolver)
        next unless adapter

        probes[name] = adapter.probe(root, runner: runner, timeout_seconds: timeout_seconds)
      end
      probes
    end
    private_class_method :probe_enabled_analyzers
  end
end
