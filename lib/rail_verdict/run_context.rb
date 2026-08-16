# frozen_string_literal: true

module RailVerdict
  class RunContext
    DETERMINISTIC_INPUTS = {
      "locale" => "C.UTF-8",
      "timezone" => "UTC",
      "ordering" => "canonical-v1"
    }.freeze

    GEMFILE_LOCK_RAILS = /^\s+rails \((\d+\.\d+\.\d+(?:\.\d+)*)\)/
    GEMFILE_LOCK_RUBY = /^\s+ruby (\d+\.\d+\.\d+)/

    attr_reader :repository_root, :revision, :ruby_version, :target_ruby_version,
                :rails_version, :analyzers, :analyzer_versions, :configuration_mode,
                :configuration_digest, :deterministic_inputs

    def self.build(repository_root:, configuration:, analyzer_versions:, revision_resolver: nil)
      root =
        begin
          File.realpath(repository_root)
        rescue Errno::ENOENT, Errno::EACCES
          raise RailVerdict::Error, "repository root does not exist: #{repository_root}"
        end
      raise RailVerdict::Error, "repository root is not a directory: #{repository_root}" unless File.directory?(root)

      revision = revision_resolver ? revision_resolver.call(root) : nil
      lockfile_text = read_lockfile(root)

      new(
        repository_root: root,
        revision: revision,
        ruby_version: RUBY_VERSION,
        target_ruby_version: lockfile_text && lockfile_text[GEMFILE_LOCK_RUBY, 1],
        rails_version: lockfile_text && lockfile_text[GEMFILE_LOCK_RAILS, 1],
        analyzers: configuration.analyzers,
        analyzer_versions: analyzer_versions,
        configuration_mode: configuration.mode,
        configuration_digest: configuration.digest,
        deterministic_inputs: DETERMINISTIC_INPUTS
      )
    end

    def self.read_lockfile(root)
      path = File.join(root, "Gemfile.lock")
      return nil unless File.file?(path)

      text = File.binread(path).force_encoding(Encoding::UTF_8)
      return nil unless text.valid_encoding?

      text
    end

    private_class_method :read_lockfile

    def initialize(repository_root:, revision:, ruby_version:, target_ruby_version:, rails_version:,
                   analyzers:, analyzer_versions:, configuration_mode:, configuration_digest:,
                   deterministic_inputs:)
      @repository_root = repository_root.dup.freeze
      @revision = revision && revision.dup.freeze
      @ruby_version = ruby_version.dup.freeze
      @target_ruby_version = target_ruby_version && target_ruby_version.dup.freeze
      @rails_version = rails_version && rails_version.dup.freeze
      @analyzers = deep_freeze(analyzers)
      @analyzer_versions = deep_freeze(analyzer_versions)
      @configuration_mode = configuration_mode.dup.freeze
      @configuration_digest = configuration_digest.dup.freeze
      @deterministic_inputs = deep_freeze(deterministic_inputs.dup)
      freeze
    end

    private

    def deep_freeze(value)
      case value
      when Hash
        value.each do |key, child|
          key.freeze if key.is_a?(String)
          deep_freeze(child)
        end
        value.freeze
      when Array
        value.each { |child| deep_freeze(child) }
        value.freeze
      when String
        value.freeze
      else
        value
      end
      value
    end
  end
end
