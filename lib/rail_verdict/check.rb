# frozen_string_literal: true

require "pathname"

module RailVerdict
  module Check
    Outcome = Struct.new(:result, :context, :configuration, :findings, keyword_init: true)

    module_function

    def execute(repository_root:, config_path:, runner: ProcessRunner, rubocop_command_resolver: nil, analyzer_timeout_seconds: 30.0, interrupted: nil)
      root = File.realpath(repository_root)
      resolved_config = resolve_config_path(root, config_path)
      configuration = Configuration.load(resolved_config)
      return interrupted_outcome if interrupted&.call

      adapter = Analyzers::RuboCop.new(command_resolver: rubocop_command_resolver)
      probe = configuration.analyzer_enabled?("rubocop") ? adapter.probe(root, runner: runner, timeout_seconds: analyzer_timeout_seconds) : nil
      context = RunContext.build(
        repository_root: root,
        configuration: configuration,
        analyzer_versions: { "rubocop" => probe&.version },
        revision_resolver: revision_resolver(root, runner)
      )
      return interrupted_outcome(context: context, configuration: configuration) if interrupted&.call

      analyzer_results = []
      findings = []
      if configuration.analyzer_enabled?("rubocop")
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

      result = Verification::Policy.evaluate(
        configuration: configuration,
        analyzer_results: analyzer_results,
        findings: findings
      )
      Outcome.new(result: result, context: context, configuration: configuration, findings: findings.freeze)
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
  end
end
