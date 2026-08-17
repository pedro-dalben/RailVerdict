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

    def not_implemented(command)
      @stderr.puts "railverdict #{command}: not yet implemented in this build step."
      EXIT_NO_GATE
    end
  end
end
