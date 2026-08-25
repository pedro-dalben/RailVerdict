# frozen_string_literal: true

require "digest"
require_relative "canonical_json"
require_relative "repository_state"
require_relative "verification_environment"

module RailVerdict
  class VerificationIdentity
    attr_reader :repository_state, :environment, :digest, :unavailable_reason, :available

    def initialize(repository_state:, environment:, digest: nil, unavailable_reason: nil, available: true)
      @repository_state = repository_state
      @environment = environment
      @digest = digest
      @unavailable_reason = unavailable_reason
      @available = available
      freeze
    end

    def available?
      @available && @repository_state&.available? && @environment&.available?
    end

    def self.capture(repository_root:, configuration_paths: nil, configuration: nil, runner: ProcessRunner, timeout_seconds: 5.0, receipt_analyzer_keys: nil)
      repo_state = RepositoryState.capture(repository_root: repository_root, configuration_paths: configuration_paths)

      unless repo_state.available?
        return new(
          repository_state: repo_state,
          environment: VerificationEnvironment.new(
            railverdict_version: RailVerdict::VERSION.to_s,
            ruby_engine: RUBY_ENGINE.to_s,
            ruby_version: RUBY_VERSION.to_s,
            analyzer_versions: {},
            digest: nil,
            unavailable_reason: repo_state.unavailable_reason,
            available: false
          ),
          digest: nil,
          unavailable_reason: "repository_state_unavailable:#{repo_state.unavailable_reason}",
          available: false
        )
      end

      config = configuration
      if config.nil? && repository_root
        begin
          # Try to load config for environment capture to know enabled analyzers
          paths = configuration_paths || Check.effective_input_paths(root: File.realpath(repository_root), config_path: File.join(File.realpath(repository_root), ".railverdict.yml"))
          config_path = paths[:config]
          config = Configuration.load(config_path) if config_path && File.file?(config_path)
        rescue StandardError
          config = nil
        end
      end

      env = if receipt_analyzer_keys
              VerificationEnvironment.capture_for_receipt(receipt_analyzer_keys, repository_root: repository_root, configuration: config, runner: runner, timeout_seconds: timeout_seconds)
            else
              VerificationEnvironment.capture(repository_root: repository_root, configuration: config, runner: runner, timeout_seconds: timeout_seconds)
            end

      unless env.available?
        return new(
          repository_state: repo_state,
          environment: env,
          digest: nil,
          unavailable_reason: env.unavailable_reason,
          available: false
        )
      end

      # Digest over both repository and environment digests
      payload = {
        "repository_digest" => repo_state.digest,
        "environment_digest" => env.digest
      }
      digest = "sha256:#{Digest::SHA256.hexdigest(CanonicalJSON.generate(payload))}"
      new(repository_state: repo_state, environment: env, digest: digest, available: true)
    rescue StandardError => error
      repo_unavailable = RepositoryState.unavailable(:capture_failed)
      env_unavailable = VerificationEnvironment.new(
        railverdict_version: RailVerdict::VERSION.to_s,
        ruby_engine: RUBY_ENGINE.to_s,
        ruby_version: RUBY_VERSION.to_s,
        analyzer_versions: {},
        digest: nil,
        unavailable_reason: error.class.to_s,
        available: false
      )
      new(repository_state: repo_unavailable, environment: env_unavailable, digest: nil, unavailable_reason: "capture_failed:#{error.class}", available: false)
    end
  end
end
