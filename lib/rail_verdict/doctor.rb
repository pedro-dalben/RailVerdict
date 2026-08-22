# frozen_string_literal: true

require "pathname"

module RailVerdict
  module Doctor
    Outcome = Struct.new(:report, :exit_code, keyword_init: true)

    module_function

    def execute(repository_root:, config_path:, runner: ProcessRunner, rubocop_command_resolver: nil)
      root = File.realpath(repository_root)
      resolved_config = resolve_config_path(root, config_path)
      configuration = Configuration.load(resolved_config)
      probes = {}
      configuration.analyzers.each do |name, selection|
        next unless selection.fetch("enabled")

        adapter = build_adapter(name, rubocop_command_resolver)
        next unless adapter

        probes[name] = adapter.probe(root, runner: runner, timeout_seconds: configuration.analyzer_timeout_seconds(name))
      end
      analyzer_versions = probes.transform_values(&:version)
      context = RunContext.build(
        repository_root: root,
        configuration: configuration,
        analyzer_versions: analyzer_versions,
        revision_resolver: ->(_root) { nil }
      )
      analyzers_report = {}
      configuration.analyzers.each do |name, selection|
        probe = probes[name]
        analyzers_report[name] = {
          "enabled" => selection.fetch("enabled"),
          "required" => selection.fetch("required"),
          "status" => probe&.status || "disabled",
          "version" => probe&.version
        }
      end
      hints = {}
      configuration.analyzers.each do |name, sel|
        probe = probes[name]
        status = probe&.status || "disabled"
        next if %w[succeeded disabled].include?(status)

        hints[name] = doctor_hint(name, probe)
      end
      baseline_hint = nil
      if configuration.mode == "no_new_debt"
        baseline_path = Baseline.resolve_path(repository_root: root, configuration: configuration)
        baseline_hint = File.file?(baseline_path) ? nil : "baseline missing for no_new_debt; run `railverdict baseline create`"
      end
      report = {
        "doctor" => "1.0",
        "ruby_version" => context.ruby_version,
        "target_ruby_version" => context.target_ruby_version,
        "rails_version" => context.rails_version,
        "configuration" => {
          "path" => relative_path(resolved_config, root),
          "valid" => true,
          "mode" => configuration.mode,
          "digest" => configuration.digest
        },
        "analyzers" => analyzers_report,
        "hints" => hints,
        "baseline_hint" => baseline_hint
      }.compact
      Outcome.new(report: report, exit_code: 0)
    rescue ConfigurationError => error
      Outcome.new(
        report: {
          "doctor" => "1.0",
          "configuration" => { "valid" => false, "error" => error.message },
          "analyzers" => {}
        },
        exit_code: 2
      )
    rescue RailVerdict::Error, SystemCallError => error
      Outcome.new(
        report: { "doctor" => "1.0", "configuration" => { "valid" => false, "error" => error.message }, "analyzers" => {} },
        exit_code: 2
      )
    end

    def resolve_config_path(root, config_path)
      path = config_path.to_s
      Pathname.new(path).absolute? ? path : File.expand_path(path, root)
    end
    private_class_method :resolve_config_path

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

    def doctor_hint(name, probe)
      msg = probe&.message.to_s
      case name
      when "rspec"
        "Add `rspec` to the target application's bundle and run bundle install. (#{msg})"
      when "minitest"
        "Add `minitest` to the target bundle or ensure tests load. (#{msg})"
      when "rubocop"
        "Add `rubocop` to the target bundle and run bundle install. (#{msg})"
      when "simplecov"
        "Generate coverage at coverage/coverage.json (SimpleCov JSON formatter) before check. (#{msg})"
      when "bundler_audit"
        "Add `bundler-audit` to the bundle; run `bundle exec bundler-audit update` separately. (#{msg})"
      else
        msg
      end
    end
    private_class_method :doctor_hint

    def relative_path(path, root)
      Pathname.new(path).relative_path_from(Pathname.new(root)).to_s
    end
    private_class_method :relative_path
  end
end
