# frozen_string_literal: true

require "optparse"

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
      not_implemented("init")
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
      not_implemented("doctor")
    end

    def command_check(argv)
      options = { config: DEFAULT_CONFIG_PATH, format: "console", changed: false, base: nil }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: railverdict check [--config PATH] [--format console|json] [--changed] [--base REV]"
        opts.on("--config PATH", String) { |value| options[:config] = value }
        opts.on("--format FORMAT", String) { |value| options[:format] = value }
        opts.on("--changed") { options[:changed] = true }
        opts.on("--base REV", String) { |value| options[:base] = value }
      end
      parse!(parser, argv)
      validate_format!(options[:format])
      if options[:changed] || options[:base]
        @stderr.puts "railverdict check: changed-scope verification (--changed/--base) is owned by Phase 4 and is not available in Phase 1."
        return EXIT_NO_GATE
      end

      not_implemented("check")
    end

    def command_baseline(argv)
      subcommand = argv.first
      raise RailVerdict::UsageError, "unknown baseline subcommand: #{subcommand.inspect}; only `baseline create` exists" unless subcommand == "create"

      options = { config: DEFAULT_CONFIG_PATH, output: nil, format: "console" }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: railverdict baseline create [--config PATH] [--output PATH] [--format console|json]"
        opts.on("--config PATH", String) { |value| options[:config] = value }
        opts.on("--output PATH", String) { |value| options[:output] = value }
        opts.on("--format FORMAT", String) { |value| options[:format] = value }
      end
      parse!(parser, argv.drop(1))
      validate_format!(options[:format])
      @stderr.puts "railverdict baseline create: baseline persistence is not implemented in Phase 1; Phase 3 owns the atomic baseline write."
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
      not_implemented("findings")
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

    def not_implemented(command)
      @stderr.puts "railverdict #{command}: not yet implemented in this build step."
      EXIT_NO_GATE
    end
  end
end
