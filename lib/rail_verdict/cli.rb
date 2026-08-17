# frozen_string_literal: true

require "optparse"
require "json"

module RailVerdict
  class CLI
    EXIT_OK = 0
    EXIT_POLICY_FAIL = 1
    EXIT_NO_GATE = 2
    EXIT_INTERRUPTED = 130

    FORMATS = %w[console json].freeze
    DEFAULT_CONFIG_PATH = ".railverdict.yml"

    USAGE = <<~USAGE
      Usage: railverdict <command> [options]

      Commands:
        init             Write the default .railverdict.yml configuration
        doctor           Report configuration and analyzer observations
        check            Run verification and print the gate result
        baseline create  Deferred boundary; Phase 3 owns baseline writes
        findings         Print normalized findings from the evidence run
        explain          Explain a finding with optional AI
        investigate      Investigate top findings with optional AI
        repair           Build a deterministic repair packet for a finding
        mcp              MCP adapter (serve)

      Global options:
        --help           Show this usage
        --version        Show the railverdict version
    USAGE

    def initialize(stdout: $stdout, stderr: $stderr, working_directory: Dir.pwd)
      @stdout = stdout
      @stderr = stderr
      @working_directory = working_directory
    end

    def run(argv)
      command = argv.first
      case command
      when nil, "-h", "--help", "help"
        @stdout.puts USAGE
        EXIT_OK
      when "--version", "-V"
        @stdout.puts "railverdict #{RailVerdict::VERSION}"
        EXIT_OK
      when "init"
        command_init(argv.drop(1))
      when "doctor"
        command_doctor(argv.drop(1))
      when "check"
        command_check(argv.drop(1))
      when "baseline"
        command_baseline(argv.drop(1))
      when "findings"
        command_findings(argv.drop(1))
      when "explain"
        command_explain(argv.drop(1))
      when "investigate"
        command_investigate(argv.drop(1))
      when "repair"
        command_repair(argv.drop(1))
      when "mcp"
        command_mcp(argv.drop(1))
      else
        @stderr.puts "railverdict: unknown command: #{command}"
        @stderr.puts USAGE
        EXIT_NO_GATE
      end
    rescue RailVerdict::UsageError => error
      @stderr.puts "railverdict: #{error.message}"
      @stderr.puts USAGE
      EXIT_NO_GATE
    end

    private

    def command_init(argv)
      options = { config: DEFAULT_CONFIG_PATH, force: false }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: railverdict init [--config PATH] [--force]"
        opts.on("--config PATH", String) { |value| options[:config] = value }
        opts.on("--force") { options[:force] = true }
      end
      parse!(parser, argv)
      exit_code, message = Init.write(
        root: @working_directory,
        config_path: options[:config],
        force: options[:force]
      )
      if exit_code.zero?
        @stdout.puts message
      else
        @stderr.puts "railverdict init: #{message}"
      end
      exit_code
    end

    def command_doctor(argv)
      options = { config: DEFAULT_CONFIG_PATH, format: "console" }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: railverdict doctor [--config PATH] [--format console|json]"
        opts.on("--config PATH", String) { |value| options[:config] = value }
        opts.on("--format FORMAT", String) { |value| options[:format] = value }
      end
      parse!(parser, argv)
      validate_format!(options[:format])
      outcome = Doctor.execute(
        repository_root: @working_directory,
        config_path: options[:config]
      )
      if options[:format] == "json"
        @stdout.write(JSON.generate(outcome.report))
        @stdout.write("\n")
      else
        @stdout.write(render_doctor_console(outcome.report))
      end
      outcome.exit_code
    end

    def command_check(argv)
      options = { config: DEFAULT_CONFIG_PATH, format: "console", changed: false, base: nil, baseline: nil, waiver: nil }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: railverdict check [--config PATH] [--format console|json] [--changed] [--base REV] [--baseline PATH] [--waiver PATH]"
        opts.on("--config PATH", String) { |value| options[:config] = value }
        opts.on("--format FORMAT", String) { |value| options[:format] = value }
        opts.on("--changed") { options[:changed] = true }
        opts.on("--base REV", String) { |value| options[:base] = value }
        opts.on("--baseline PATH", String) { |value| options[:baseline] = value }
        opts.on("--waiver PATH", String) { |value| options[:waiver] = value }
      end
      parse!(parser, argv)
      validate_format!(options[:format])
      if options[:base] && !options[:changed]
        raise RailVerdict::UsageError, "--base requires --changed"
      end

      outcome, interrupted = execute_check(options)
      return EXIT_NO_GATE unless render_result(outcome.result, options[:format])

      exit_code_for(outcome.result, interrupted: interrupted)
    end

    def command_baseline(argv)
      subcommand = argv.first
      raise RailVerdict::UsageError, "unknown baseline subcommand: #{subcommand.inspect}; only `baseline create` exists" unless subcommand == "create"

      options = { config: DEFAULT_CONFIG_PATH, output: nil, format: "console", force: false }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: railverdict baseline create [--config PATH] [--output PATH] [--format console|json] [--force]"
        opts.on("--config PATH", String) { |value| options[:config] = value }
        opts.on("--output PATH", String) { |value| options[:output] = value }
        opts.on("--format FORMAT", String) { |value| options[:format] = value }
        opts.on("--force") { options[:force] = true }
      end
      parse!(parser, argv.drop(1))
      validate_format!(options[:format])

      outcome, interrupted = execute_check({ config: options[:config], format: options[:format] })
      return EXIT_INTERRUPTED if interrupted || outcome.result.completion_status == "interrupted"
      unless outcome.result.completion_status == "complete"
        @stderr.puts "railverdict baseline create: refusing to create baseline from incomplete run (#{outcome.result.operational_failures.map { |failure| failure.fetch('code') }.join(', ')})"
        return EXIT_NO_GATE
      end
      if outcome.context.nil? || outcome.configuration.nil?
        @stderr.puts "railverdict baseline create: refusing to create baseline without a complete context"
        return EXIT_NO_GATE
      end

      path = Baseline.resolve_path(repository_root: @working_directory, configuration: outcome.configuration, output_override: options[:output])
      baseline = Baseline.create(
        findings: outcome.findings,
        configuration: outcome.configuration,
        analyzer_versions: outcome.context.analyzer_versions,
        clock: Time.now.utc
      )
      Baseline.write(path: path, baseline: baseline, force: options[:force])

      if options[:format] == "json"
        @stdout.write(JSON.generate({ "baseline" => baseline.to_h }) + "\n")
      else
        @stdout.puts "Baseline created at #{path} (#{baseline.entries.length} entries)"
      end
      EXIT_OK
    rescue RailVerdict::UsageError => error
      @stderr.puts "railverdict baseline create: #{error.message}"
      EXIT_NO_GATE
    rescue RailVerdict::Baseline::IncompatibleError, RailVerdict::Error => error
      @stderr.puts "railverdict baseline create: #{error.message}"
      EXIT_NO_GATE
    end

    def command_findings(argv)
      options = { config: DEFAULT_CONFIG_PATH, format: "console" }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: railverdict findings [--config PATH] [--format console|json]"
        opts.on("--config PATH", String) { |value| options[:config] = value }
        opts.on("--format FORMAT", String) { |value| options[:format] = value }
      end
      parse!(parser, argv)
      validate_format!(options[:format])
      outcome, interrupted = execute_check(options)
      if options[:format] == "json"
        @stdout.write(JSON.generate(FindingsCommand.document(outcome)))
        @stdout.write("\n")
      else
        @stdout.write(FindingsCommand.console(outcome))
      end
      @stderr.puts "railverdict findings: required evidence is incomplete" if outcome.result.incomplete?
      return EXIT_INTERRUPTED if interrupted || outcome.result.completion_status == "interrupted"
      return EXIT_NO_GATE if outcome.result.incomplete?

      EXIT_OK
    end

    def parse!(parser, argv)
      rest = parser.parse(argv.dup)
      return if rest.empty?

      raise RailVerdict::UsageError, "unexpected arguments: #{rest.join(' ')}"
    rescue OptionParser::ParseError => error
      raise RailVerdict::UsageError, error.message
    end

    def validate_format!(format)
      return if FORMATS.include?(format)

      raise RailVerdict::UsageError, "invalid --format #{format.inspect}; expected console or json"
    end

    def execute_check(options)
      interrupted = false
      previous = Signal.trap("INT") do
        interrupted = true
        RailVerdict::ProcessRunner.registry.terminate_all
      end
      execute_options = {
        repository_root: @working_directory,
        config_path: options[:config],
        interrupted: -> { interrupted }
      }
      execute_options[:baseline_path_override] = options[:baseline] if options.key?(:baseline) && options[:baseline]
      execute_options[:waiver_path_override] = options[:waiver] if options.key?(:waiver) && options[:waiver]
      execute_options[:baseline_path_override] = options[:output] if options.key?(:output) && options[:output]
      execute_options[:changed] = options[:changed] if options.key?(:changed)
      execute_options[:base] = options[:base] if options.key?(:base)
      outcome = Check.execute(**execute_options)
      [outcome, interrupted]
    ensure
      Signal.trap("INT", previous) if previous
    end

    def render_result(result, format)
      rendered = if format == "json"
        Reporters::JsonReporter.render(result)
      else
        Reporters::Console.render(result)
      end
      @stdout.write(rendered)
      true
    rescue RailVerdict::Error => error
      @stderr.puts "railverdict: #{error.message}"
      false
    end

    def exit_code_for(result, interrupted: false)
      return EXIT_INTERRUPTED if interrupted || result.completion_status == "interrupted"
      return EXIT_NO_GATE if result.completion_status != "complete"
      return EXIT_POLICY_FAIL if result.gate == "FAIL"

      EXIT_OK
    end

    def render_doctor_console(report)
      lines = ["RailVerdict doctor", "", "Ruby: #{report['ruby_version'] || 'unknown'}"]
      lines << "Target Ruby: #{report['target_ruby_version']}" if report.key?("target_ruby_version")
      lines << "Rails: #{report['rails_version']}" if report.key?("rails_version")
      configuration = report.fetch("configuration")
      lines << "Configuration: #{configuration['valid'] ? 'valid' : 'invalid'}"
      report.fetch("analyzers", {}).each do |name, details|
        lines << "#{name}: #{details['status']}#{details['version'] ? " (#{details['version']})" : ''}"
      end
      lines.join("\n") + "\n"
    end

    def command_explain(argv)
      finding_ref = argv.first
      raise RailVerdict::UsageError, "explain requires a finding id or fingerprint" unless finding_ref && !finding_ref.start_with?("-")

      options = { config: DEFAULT_CONFIG_PATH, format: "console", preview: false }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: railverdict explain <finding-id|fingerprint> [--config PATH] [--format console|json] [--preview-context]"
        opts.on("--config PATH", String) { |v| options[:config] = v }
        opts.on("--format FORMAT", String) { |v| options[:format] = v }
        opts.on("--preview-context") { options[:preview] = true }
      end
      parse!(parser, argv.drop(1))
      validate_format!(options[:format])

      outcome, interrupted = execute_check({ config: options[:config], format: options[:format] })
      return EXIT_INTERRUPTED if interrupted

      if options[:preview]
        return explain_preview(outcome, finding_ref, options[:format])
      end

      result = Intelligence::Orchestrator.explain(
        outcome: outcome,
        finding_ref: finding_ref,
        configuration: outcome.configuration
      )
      render_intelligence(result, options[:format])
      EXIT_OK
    rescue RailVerdict::UsageError => e
      @stderr.puts "railverdict explain: #{e.message}"
      EXIT_NO_GATE
    rescue StandardError => e
      @stderr.puts "railverdict explain: #{e.message}"
      EXIT_NO_GATE
    end

    def command_investigate(argv)
      options = { config: DEFAULT_CONFIG_PATH, format: "console", preview: false, limit: 3 }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: railverdict investigate [--config PATH] [--format console|json] [--preview-context] [--limit N]"
        opts.on("--config PATH", String) { |v| options[:config] = v }
        opts.on("--format FORMAT", String) { |v| options[:format] = v }
        opts.on("--preview-context") { options[:preview] = true }
        opts.on("--limit N", Integer) { |v| options[:limit] = v }
      end
      parse!(parser, argv)
      validate_format!(options[:format])

      outcome, interrupted = execute_check({ config: options[:config], format: options[:format] })
      return EXIT_INTERRUPTED if interrupted

      if options[:preview]
        findings = Intelligence::Budget.select_findings(outcome.findings || [], limit: [options[:limit], 3].min)
        manifests = findings.map do |f|
          Intelligence::ContextBuilder.build(outcome: outcome, finding_ref: f.id).to_json_hash rescue {}
        end
        if options[:format] == "json"
          @stdout.write(JSON.generate({ "manifests" => manifests }) + "\n")
        else
          @stdout.puts "Preview: #{manifests.length} findings selected"
          manifests.each { |m| @stdout.puts "  #{m['finding_id']} #{m['fingerprint']}" }
        end
        return EXIT_OK
      end

      results = Intelligence::Orchestrator.investigate(
        outcome: outcome,
        configuration: outcome.configuration,
        limit: options[:limit]
      )
      results.each { |r| render_intelligence(r, options[:format]) }
      EXIT_OK
    rescue RailVerdict::UsageError => e
      @stderr.puts "railverdict investigate: #{e.message}"
      EXIT_NO_GATE
    rescue StandardError => e
      @stderr.puts "railverdict investigate: #{e.message}"
      EXIT_NO_GATE
    end

    def explain_preview(outcome, finding_ref, format)
      manifest = Intelligence::ContextBuilder.build(outcome: outcome, finding_ref: finding_ref)
      if format == "json"
        @stdout.write(JSON.generate(manifest.to_json_hash) + "\n")
      else
        @stdout.puts "Finding: #{manifest.finding_id}"
        @stdout.puts "Fingerprint: #{manifest.fingerprint}"
        @stdout.puts "Snippets: #{manifest.snippets.length}"
        manifest.snippets.each { |s| @stdout.puts "  #{s['path']}" }
      end
      EXIT_OK
    rescue ArgumentError => e
      @stderr.puts "railverdict explain: #{e.message}"
      EXIT_NO_GATE
    end

    def render_intelligence(result, format)
      if result[:failure]
        if format == "json"
          @stdout.write(JSON.generate({ "failure" => result[:failure].to_h }) + "\n")
        else
          @stdout.puts "Intelligence: #{result[:failure].code}: #{result[:failure].message}"
        end
      elsif result[:analysis]
        if format == "json"
          @stdout.write(JSON.generate(result[:analysis].to_h) + "\n")
        else
          @stdout.puts "Analysis: #{result[:analysis].summary} (confidence: #{result[:analysis].confidence})"
        end
      end
    end

    def command_repair(argv)
      finding_ref = argv.first
      raise RailVerdict::UsageError, "repair requires a finding id or fingerprint" unless finding_ref && !finding_ref.start_with?("-")

      options = { config: DEFAULT_CONFIG_PATH, format: "console", output: nil, changed: false, base: nil, baseline: nil, waiver: nil }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: railverdict repair <finding-id|fingerprint> [--config PATH] [--format console|json] [--output PATH] [--changed] [--base REV] [--baseline PATH] [--waiver PATH]"
        opts.on("--config PATH", String) { |v| options[:config] = v }
        opts.on("--format FORMAT", String) { |v| options[:format] = v }
        opts.on("--output PATH", String) { |v| options[:output] = v }
        opts.on("--changed") { options[:changed] = true }
        opts.on("--base REV", String) { |v| options[:base] = v }
        opts.on("--baseline PATH", String) { |v| options[:baseline] = v }
        opts.on("--waiver PATH", String) { |v| options[:waiver] = v }
      end
      parse!(parser, argv.drop(1))
      validate_format!(options[:format])
      raise RailVerdict::UsageError, "--base requires --changed" if options[:base] && !options[:changed]

      code, _packet = RailVerdict::Repair::Command.execute(
        repository_root: @working_directory,
        config_path: options[:config],
        finding_ref: finding_ref,
        format: options[:format],
        output_path: options[:output],
        changed: options[:changed],
        base: options[:base],
        baseline_override: options[:baseline],
        waiver_override: options[:waiver],
        stdout: @stdout,
        stderr: @stderr
      )
      code
    rescue RailVerdict::UsageError => e
      @stderr.puts "railverdict repair: #{e.message}"
      EXIT_NO_GATE
    end

    def command_mcp(argv)
      sub = argv.first
      raise RailVerdict::UsageError, "mcp requires subcommand: serve" unless sub == "serve"

      options = { repository_root: @working_directory }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: railverdict mcp serve [--repository-root PATH]"
        opts.on("--repository-root PATH", String) { |v| options[:repository_root] = v }
      end
      parse!(parser, argv.drop(1))
      require_relative "mcp"
      server = RailVerdict::MCP::Server.new(repository_root: options[:repository_root])
      server.serve
      EXIT_OK
    rescue RailVerdict::UsageError => e
      @stderr.puts "railverdict mcp: #{e.message}"
      EXIT_NO_GATE
    rescue StandardError => e
      @stderr.puts "railverdict mcp: #{e.message}"
      EXIT_NO_GATE
    end

    def not_implemented(command)
      @stderr.puts "railverdict #{command}: not yet implemented in this build step."
      EXIT_NO_GATE
    end
  end
end
