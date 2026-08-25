# frozen_string_literal: true

require "digest"
require_relative "canonical_json"
require_relative "process_runner"

module RailVerdict
  class VerificationEnvironment
    MAX_ENV_PROBE_BYTES = 64 * 1024
    MAX_PROBE_TIMEOUT = 5.0

    attr_reader :railverdict_version, :ruby_engine, :ruby_version, :analyzer_versions, :digest, :unavailable_reason, :available

    def initialize(railverdict_version:, ruby_engine:, ruby_version:, analyzer_versions:, digest: nil, unavailable_reason: nil, available: true)
      @railverdict_version = railverdict_version
      @ruby_engine = ruby_engine
      @ruby_version = ruby_version
      @analyzer_versions = analyzer_versions.freeze
      @digest = digest
      @unavailable_reason = unavailable_reason
      @available = available
      freeze
    end

    def available?
      @available
    end

    def self.capture(repository_root:, configuration: nil, runner: ProcessRunner, timeout_seconds: MAX_PROBE_TIMEOUT)
      railverdict_version = RailVerdict::VERSION.to_s
      ruby_engine = RUBY_ENGINE.to_s
      ruby_version = RUBY_VERSION.to_s

      config = configuration
      if config.nil? && repository_root
        begin
          root_real = File.realpath(repository_root)
          config_path = File.join(root_real, ".railverdict.yml")
          config = Configuration.load(config_path) if File.file?(config_path)
        rescue StandardError
          config = nil
        end
      end

      analyzer_versions = {}
      probes_failed = []
      if config
        config.analyzers.each do |name, selection|
          next unless selection.fetch("enabled")

          adapter_class = Check::REGISTRY[name]
          next unless adapter_class

          adapter = build_adapter(name)
          next unless adapter

          probe_timeout = resolve_probe_timeout(config, name, timeout_seconds)
          probe = probe_adapter(adapter, repository_root, runner, probe_timeout)
          # Fallback for bundle exec failures in cloned fixtures without bundle install
          if probe.nil? || probe.status != "succeeded"
            fallback = probe_fallback(name, repository_root, runner, probe_timeout)
            probe = fallback if fallback && fallback.status == "succeeded"
          end
          if name.to_s == "simplecov" && probe && probe.status == "unavailable" && probe.message.to_s.include?("coverage file is absent")
            # SimpleCov without coverage file is not a version-probe failure; skip it
            next
          end
          if probe.nil? || probe.status != "succeeded" || probe.version.nil? || probe.version.to_s.strip.empty?
            # Non-required analyzers failing probe should not make environment unavailable; they are advisory
            if selection["required"] == false
              next
            end
            probes_failed << name
            next
          end
          version = RailVerdict::Analyzers::Shared.canonical_tool_version(probe.version)
          analyzer_versions[name.to_s] = version
        end
      else
        # No configuration observable -> try all known analyzers that are present?
        # Conservative: probe all registry entries cheaply; only succeeded probes contribute.
        # Missing probes do not make unavailable if no config exists; use empty relevant set.
      end

      # If any enabled analyzer probe failed, environment is unobservable fail-closed
      unless probes_failed.empty?
        return new(
          railverdict_version: railverdict_version,
          ruby_engine: ruby_engine,
          ruby_version: ruby_version,
          analyzer_versions: analyzer_versions.sort.to_h,
          digest: nil,
          unavailable_reason: "analyzer_version_unobservable:#{probes_failed.sort.join(',')}",
          available: false
        )
      end

      # Detect "unknown" canonicalized versions as unobservable as well
      unknown_keys = analyzer_versions.select { |_, v| v == "unknown" }.keys
      unless unknown_keys.empty?
        return new(
          railverdict_version: railverdict_version,
          ruby_engine: ruby_engine,
          ruby_version: ruby_version,
          analyzer_versions: analyzer_versions.sort.to_h,
          digest: nil,
          unavailable_reason: "analyzer_version_unobservable:#{unknown_keys.sort.join(',')}",
          available: false
        )
      end

      sorted = analyzer_versions.sort.to_h
      payload = {
        "railverdict_version" => railverdict_version,
        "ruby_engine" => ruby_engine,
        "ruby_version" => ruby_version,
        "analyzer_versions" => sorted
      }
      digest = "sha256:#{Digest::SHA256.hexdigest(CanonicalJSON.generate(payload))}"
      new(
        railverdict_version: railverdict_version,
        ruby_engine: ruby_engine,
        ruby_version: ruby_version,
        analyzer_versions: sorted,
        digest: digest,
        available: true
      )
    rescue StandardError => error
      new(
        railverdict_version: RailVerdict::VERSION.to_s,
        ruby_engine: RUBY_ENGINE.to_s,
        ruby_version: RUBY_VERSION.to_s,
        analyzer_versions: {},
        digest: nil,
        unavailable_reason: "environment_capture_failed:#{error.class}",
        available: false
      )
    end

    def self.capture_for_receipt(receipt_analyzer_keys, repository_root:, configuration: nil, runner: ProcessRunner, timeout_seconds: MAX_PROBE_TIMEOUT)
      # Only probe analyzers that are relevant (present in receipt)
      keys = Array(receipt_analyzer_keys).map(&:to_s)
      return capture(repository_root: repository_root, configuration: configuration, runner: runner, timeout_seconds: timeout_seconds) if keys.empty?

      env = capture(repository_root: repository_root, configuration: configuration, runner: runner, timeout_seconds: timeout_seconds)
      return env unless env.available?

      # Filter to only relevant keys, but if any relevant key missing from current env -> stale (drift)
      # The unavailable check already handled probe failures for enabled analyzers.
      # Here we need to ensure we return only relevant versions for comparison.
      filtered = env.analyzer_versions.select { |k, _| keys.include?(k) }
      # If a relevant analyzer is now disabled in config but was in receipt, it's drift -> but we keep filtered empty; caller will detect mismatch
      payload = {
        "railverdict_version" => env.railverdict_version,
        "ruby_engine" => env.ruby_engine,
        "ruby_version" => env.ruby_version,
        "analyzer_versions" => filtered.sort.to_h
      }
      digest = "sha256:#{Digest::SHA256.hexdigest(CanonicalJSON.generate(payload))}"
      new(
        railverdict_version: env.railverdict_version,
        ruby_engine: env.ruby_engine,
        ruby_version: env.ruby_version,
        analyzer_versions: filtered.sort.to_h,
        digest: digest,
        available: true
      )
    end

    private_class_method def self.build_adapter(name)
      case name
      when "rubocop" then RailVerdict::Analyzers::RuboCop.new
      when "minitest" then RailVerdict::Analyzers::Minitest.new
      when "rspec" then RailVerdict::Analyzers::RSpec.new
      when "simplecov" then RailVerdict::Analyzers::SimpleCov.new
      when "bundler_audit" then RailVerdict::Analyzers::BundlerAudit.new
      end
    rescue StandardError
      nil
    end

    private_class_method def self.probe_adapter(adapter, root, runner, timeout)
      adapter.probe(root, runner: runner, timeout_seconds: timeout)
    rescue StandardError
      nil
    end

    private_class_method def self.probe_fallback(name, root, runner, timeout)
      # Try direct executable without bundle for version probing
      cmd = case name.to_s
            when "rubocop" then { executable: "rubocop", args_prefix: [] }
            when "rspec" then { executable: "rspec", args_prefix: [] }
            when "bundler_audit" then { executable: "bundler-audit", args_prefix: [] }
            when "minitest" then { executable: "ruby", args_prefix: ["-rminitest", "-e", "puts Minitest::VERSION"] }
            else nil
            end
      return nil unless cmd

      # Create a temporary adapter with fallback command resolver
      fallback_adapter = case name.to_s
                         when "rubocop" then RailVerdict::Analyzers::RuboCop.new(command_resolver: ->(_) { cmd })
                         when "rspec" then RailVerdict::Analyzers::RSpec.new(command_resolver: ->(_) { cmd })
                         when "bundler_audit" then RailVerdict::Analyzers::BundlerAudit.new(command_resolver: ->(_) { cmd })
                         when "minitest" then RailVerdict::Analyzers::Minitest.new(command_resolver: ->(_) { cmd })
                         else nil
                         end
      return nil unless fallback_adapter

      fallback_adapter.probe(root, runner: runner, timeout_seconds: timeout)
    rescue StandardError
      nil
    end

    private_class_method def self.resolve_probe_timeout(config, name, default)
      config.analyzer_timeout_seconds(name.to_s) || [default, 5.0].min
    rescue StandardError
      [default, 5.0].min
    end
  end
end
