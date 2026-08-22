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

    def execute(repository_root:, config_path:, runner: ProcessRunner, rubocop_command_resolver: nil, analyzer_timeout_seconds: 30.0, interrupted: nil, baseline_path_override: nil, waiver_path_override: nil, clock: Time.now.utc, changed: false, base: nil)
      root = File.realpath(repository_root)
      resolved_config = resolve_config_path(root, config_path)
      configuration = Configuration.load(resolved_config)
      return interrupted_outcome if interrupted&.call

      probes = probe_enabled_analyzers(root, configuration, runner: runner, rubocop_command_resolver: rubocop_command_resolver, default_timeout_seconds: analyzer_timeout_seconds)

      analyzer_versions = probes.transform_values(&:version)

      git_context = nil
      git_error = nil
      if changed
        begin
          git_context = Git::Context.build(repository_root: root, base_override: base, configuration: configuration, runner: runner)
        rescue Git::Error => error
          git_error = error
        end
        if git_error
          git_incomplete = Verification::Policy.incomplete_result(
            analyzer_results: [],
            findings: [],
            operational_failures: [{ "code" => "failed", "message" => git_error.message }],
            code: "git_scope_failed",
            message: git_error.message
          )
          context_for_error = begin
            RunContext.build(repository_root: root, configuration: configuration, analyzer_versions: analyzer_versions, revision_resolver: revision_resolver(root, runner))
          rescue StandardError
            nil
          end
          git_payload = git_error_payload(git_error, base, configuration)
          enriched = GateResult.new(
            completion_status: git_incomplete.completion_status,
            gate: git_incomplete.gate,
            policy_status: git_incomplete.policy_status,
            findings: git_incomplete.findings,
            analyzer_results: git_incomplete.analyzer_results,
            operational_failures: git_incomplete.operational_failures,
            decision_reasons: git_incomplete.decision_reasons,
            git: git_payload
          )
          return Outcome.new(result: enriched, context: context_for_error, configuration: configuration, findings: [].freeze)
        end
      end

      context = RunContext.build(
        repository_root: root,
        configuration: configuration,
        analyzer_versions: analyzer_versions,
        revision_resolver: revision_resolver(root, runner),
        git_context: git_context
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
        timeout_seconds = resolve_timeout_seconds(configuration, name, analyzer_timeout_seconds)
        analyzer_result, analyzer_findings = adapter.run(
          root,
          runner: runner,
          probe_result: probe,
          timeout_seconds: timeout_seconds
        )
        analyzer_results << analyzer_result
        findings.concat(analyzer_findings)
      end
      return interrupted_outcome(context: context, configuration: configuration, analyzer_results: analyzer_results, findings: findings) if interrupted&.call

      baseline = nil
      baseline_meta = nil
      comparison = nil
      classified_findings = findings
      waivers = []
      waiver_meta = nil
      resolved_baseline_path = Baseline.resolve_path(repository_root: root, configuration: configuration, output_override: baseline_path_override)
      resolved_waiver_path = WaiverStore.resolve_path(repository_root: root, configuration: configuration, waiver_override: waiver_path_override)
      begin
        waivers = WaiverStore.read_optional(resolved_waiver_path)
        waiver_meta = { "loaded" => !waivers.empty?, "path" => resolved_waiver_path, "count" => waivers.length }
      rescue Waiver::IncompatibleError => error
        incomplete = Verification::Policy.incomplete_result(
          analyzer_results: analyzer_results,
          findings: findings,
          operational_failures: [{ "code" => "failed", "message" => error.message }],
          code: "waiver_incompatible",
          message: error.message
        )
        enriched = GateResult.new(completion_status: incomplete.completion_status, gate: incomplete.gate, policy_status: incomplete.policy_status, findings: incomplete.findings, analyzer_results: incomplete.analyzer_results, operational_failures: incomplete.operational_failures, decision_reasons: incomplete.decision_reasons, baseline: nil, comparison: { "counts" => {}, "waiver_error" => error.message })
        return Outcome.new(result: enriched, context: context, configuration: configuration, findings: findings.freeze)
      end
      rename_map = git_context ? git_context.rename_map : nil
      begin
        if File.file?(resolved_baseline_path)
          loaded = Baseline.read(resolved_baseline_path)
          baseline = loaded
          baseline_meta = { "loaded" => true, "path" => resolved_baseline_path, "schema_version" => Baseline::SCHEMA_VERSION, "fingerprint_version" => Fingerprint::VERSION, "compatible" => true }
          cmp = Comparison.classify(findings: findings, baseline: loaded, waivers: waivers.map(&:to_h), clock: clock, rename_map: rename_map)
          comparison = { "counts" => cmp.counts, "introduced" => cmp.introduced.map(&:fingerprint).sort, "existing" => cmp.existing.map(&:fingerprint).sort, "resolved" => cmp.resolved.map { |entry| entry.fetch("fingerprint") }.sort, "changed" => cmp.changed.map(&:fingerprint).sort, "moved" => cmp.moved.map(&:fingerprint).sort, "waived" => cmp.counts.fetch("waived", 0) == 0 ? [] : cmp.classified_findings.select { |item| item.state == "waived" }.map(&:fingerprint).sort, "orphaned_waivers" => cmp.orphaned_waivers.map { |w| w["fingerprint"] || w[:fingerprint] }.compact.sort }
          if waiver_meta
            comparison["waivers"] = waiver_meta
          end
          classified_findings = cmp.classified_findings
        elsif waiver_meta && waiver_meta["count"] > 0
          cmp = Comparison.classify(findings: findings, baseline: nil, waivers: waivers.map(&:to_h), clock: clock, rename_map: rename_map)
          comparison = { "counts" => cmp.counts, "introduced" => cmp.introduced.map(&:fingerprint).sort, "existing" => cmp.existing.map(&:fingerprint).sort, "resolved" => cmp.resolved.map { |entry| entry.fetch("fingerprint") }.sort, "changed" => cmp.changed.map(&:fingerprint).sort, "moved" => cmp.moved.map(&:fingerprint).sort, "waived" => cmp.counts.fetch("waived", 0) == 0 ? [] : cmp.classified_findings.select { |item| item.state == "waived" }.map(&:fingerprint).sort, "orphaned_waivers" => cmp.orphaned_waivers.map { |w| w["fingerprint"] || w[:fingerprint] }.compact.sort, "waivers" => waiver_meta }
          classified_findings = cmp.classified_findings
        elsif waiver_meta
          comparison = nil
        end
      rescue Baseline::IncompatibleError => error
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

      unless git_context.nil?
        analyzer_results = attach_changed_coverage(analyzer_results: analyzer_results, git_context: git_context)
      end

      filtered_findings_for_policy = classified_findings
      changed_filter_active = !git_context.nil?
      if changed_filter_active
        filtered_findings_for_policy = classified_findings
      end

      result = Verification::Policy.evaluate(
        configuration: configuration,
        analyzer_results: analyzer_results,
        findings: filtered_findings_for_policy,
        comparison: comparison,
        baseline_meta: baseline_meta,
        git_context: git_context
      )

      git_payload = nil
      if git_context
        git_payload = build_git_payload(git_context, root)
      end

      rails_context_h = nil
      begin
        rails_ctx = RailsContext::Context.build(repository_root: root, git_context: git_context)
        rails_context_h = rails_ctx.to_h
      rescue StandardError
        rails_context_h = nil
      end

      if baseline_meta || comparison || git_payload || rails_context_h
        result = GateResult.new(
          completion_status: result.completion_status,
          gate: result.gate,
          policy_status: result.policy_status,
          findings: result.findings,
          analyzer_results: result.analyzer_results,
          operational_failures: result.operational_failures,
          decision_reasons: result.decision_reasons,
          baseline: baseline_meta,
          comparison: comparison,
          git: git_payload,
          rails_context: rails_context_h
        )
      elsif git_payload && result.complete?
        result = GateResult.new(
          completion_status: result.completion_status,
          gate: result.gate,
          policy_status: result.policy_status,
          findings: result.findings,
          analyzer_results: result.analyzer_results,
          operational_failures: result.operational_failures,
          decision_reasons: result.decision_reasons,
          git: git_payload,
          rails_context: rails_context_h
        )
      elsif git_payload
        result = GateResult.new(
          completion_status: result.completion_status,
          gate: result.gate,
          policy_status: result.policy_status,
          findings: result.findings,
          analyzer_results: result.analyzer_results,
          operational_failures: result.operational_failures,
          decision_reasons: result.decision_reasons,
          git: git_payload,
          rails_context: rails_context_h
        )
      elsif rails_context_h
        result = GateResult.new(
          completion_status: result.completion_status,
          gate: result.gate,
          policy_status: result.policy_status,
          findings: result.findings,
          analyzer_results: result.analyzer_results,
          operational_failures: result.operational_failures,
          decision_reasons: result.decision_reasons,
          rails_context: rails_context_h
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

    def git_error_payload(error, base_override, configuration)
      base_for_payload = base_override && !base_override.to_s.strip.empty? ? base_override.to_s.strip : (configuration.respond_to?(:git_base) ? configuration.git_base : nil)
      {
        "head" => nil,
        "base" => base_for_payload,
        "merge_base" => nil,
        "changed_files" => [],
        "changed_line_set" => {},
        "binary_paths" => [],
        "conflicted_paths" => [],
        "error" => error.class.name.split("::").last,
        "error_message" => error.message
      }
    end
    private_class_method :git_error_payload

    def build_git_payload(git_context, root)
      changed_files = git_context.changed_files.map do |file|
        entry = { "status" => file.status.to_s, "path" => file.path, "score" => file.score }
        entry["old_path"] = file.old_path if file.old_path
        entry["new_path"] = file.new_path if file.new_path
        entry["binary"] = file.binary if file.respond_to?(:binary) && !file.binary.nil?
        entry
      end.sort_by { |entry| entry["path"].to_s }
      {
        "repository_root" => File.basename(root),
        "head" => git_context.head,
        "base" => git_context.base,
        "merge_base" => git_context.merge_base,
        "changed_files" => changed_files,
        "changed_line_set" => git_context.changed_line_set.transform_keys(&:to_s).transform_values { |lines| lines.sort },
        "binary_paths" => git_context.binary_paths.sort,
        "conflicted_paths" => git_context.conflicted_paths.sort
      }
    end
    private_class_method :build_git_payload

    def attach_changed_coverage(analyzer_results:, git_context:)
      analyzer_results.map do |result|
        next result unless result.analyzer == "simplecov"
        next result unless result.execution_status == "succeeded"

        summary = result.evidence_summary
        next result unless summary.is_a?(Hash)

        coverage_doc = summary["_coverage_document"]
        document = coverage_doc || summary_to_coverage_document(summary)
        next result unless document

        line_set = git_context.changed_line_set
        begin
          changed = Coverage::ChangedLineEvaluator.evaluate(coverage_document: document, line_set: line_set)
        rescue ArgumentError
          next result
        end
        new_summary = summary.dup
        new_summary.delete("_coverage_document")
        new_summary["changed_line_coverage"] = changed
        new_summary["changed_line_set"] = line_set.transform_keys(&:to_s).transform_values { |lines| lines.sort }
        AnalyzerResult.new(
          analyzer: result.analyzer,
          tool_version: result.tool_version,
          invocation: result.invocation,
          execution_status: result.execution_status,
          finding_ids: result.finding_ids,
          evidence_summary: new_summary
        )
      end
    end
    private_class_method :attach_changed_coverage

    def summary_to_coverage_document(summary)
      files = summary["files"] || summary["_files"]
      return nil unless files.is_a?(Array)

      { "files" => files }
    end
    private_class_method :summary_to_coverage_document

    def probe_enabled_analyzers(root, configuration, runner:, rubocop_command_resolver:, default_timeout_seconds:)
      probes = {}
      configuration.analyzers.each do |name, selection|
        next unless selection.fetch("enabled")

        adapter_class = REGISTRY[name]
        next unless adapter_class

        adapter = build_adapter(name, rubocop_command_resolver)
        next unless adapter

        timeout_seconds = resolve_timeout_seconds(configuration, name, default_timeout_seconds)
        probes[name] = adapter.probe(root, runner: runner, timeout_seconds: timeout_seconds)
      end
      probes
    end
    private_class_method :probe_enabled_analyzers

    def resolve_timeout_seconds(configuration, analyzer_name, default_timeout_seconds)
      configuration.analyzer_timeout_seconds(analyzer_name.to_s) || default_timeout_seconds
    end
    private_class_method :resolve_timeout_seconds
  end
end
