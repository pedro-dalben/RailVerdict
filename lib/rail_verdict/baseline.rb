# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "pathname"
require "securerandom"
require "tempfile"
require "time"

module RailVerdict
  class Baseline
    SCHEMA_VERSION = "1.0"
    DEFAULT_FILENAME = ".railverdict-baseline.json"

    class IncompatibleError < RailVerdict::Error; end

    attr_reader :hash, :entries, :created_at, :configuration_digest, :analyzer_versions

    def initialize(hash)
      @hash = hash.freeze
      @entries = hash.fetch("entries").freeze
      @created_at = hash.fetch("created_at").freeze
      @configuration_digest = hash.fetch("configuration_digest").freeze
      @analyzer_versions = hash.fetch("analyzer_versions").freeze
      freeze
    end

    def to_h
      @hash
    end

    def fingerprint_set
      @fingerprint_set ||= Set.new(@entries.map { |entry| entry.fetch("fingerprint") }).freeze
    end

    def entry_by_fingerprint
      @entry_by_fingerprint ||= @entries.to_h { |entry| [entry.fetch("fingerprint"), entry] }.freeze
    end

    def self.create(findings:, configuration:, analyzer_versions:, clock: Time.now.utc)
      created_at = clock.utc.iso8601
      entries = findings.sort_by(&:sort_key).map do |finding|
        {
          "fingerprint" => finding.fingerprint,
          "analyzer" => finding.analyzer,
          "rule_id" => finding.rule_id,
          "path" => finding.location.fetch("path"),
          "message" => finding.message,
          "first_seen" => created_at
        }
      end
      entries = entries.uniq { |entry| entry.fetch("fingerprint") }.sort_by { |entry| entry.fetch("fingerprint") }
      hash = {
        "schema_version" => SCHEMA_VERSION,
        "fingerprint_version" => Fingerprint::VERSION,
        "algorithm" => Fingerprint::ALGORITHM,
        "payload_schema" => Fingerprint::PAYLOAD_SCHEMA,
        "created_at" => created_at,
        "created_by" => "railverdict #{RailVerdict::VERSION}",
        "configuration_digest" => configuration.digest,
        "analyzer_versions" => analyzer_versions.transform_keys(&:to_s).sort.to_h,
        "entries" => entries
      }
      errors = SchemaValidator.validate_baseline(hash)
      raise IncompatibleError, "baseline validation failed: #{errors.join('; ')}" unless errors.empty?

      new(hash)
    end

    def self.default_path(repository_root)
      File.join(File.realpath(repository_root), DEFAULT_FILENAME)
    end

    def self.resolve_path(repository_root:, configuration:, output_override: nil)
      root = File.realpath(repository_root)
      if output_override && !output_override.to_s.strip.empty?
        path = output_override.to_s
        return Pathname.new(path).absolute? ? path : File.expand_path(path, root)
      end
      if configuration.respond_to?(:baseline_path) && configuration.baseline_path
        configured = configuration.baseline_path.to_s
        return Pathname.new(configured).absolute? ? configured : File.expand_path(configured, root)
      end
      File.join(root, DEFAULT_FILENAME)
    end

    def self.write(path:, baseline:, force: false)
      if File.exist?(path) && !force
        raise UsageError, "baseline already exists at #{path}; use --force to overwrite"
      end
      dir = File.dirname(File.expand_path(path))
      FileUtils.mkdir_p(dir)
      tmp = File.join(dir, ".#{File.basename(path)}.tmp.#{Process.pid}.#{SecureRandom.hex(8)}")
      begin
        File.open(tmp, "wb", 0o600) do |file|
          file.write(JSON.pretty_generate(baseline.to_h) + "\n")
          file.flush
          file.fsync
        end
        errors = SchemaValidator.validate_baseline(baseline.to_h)
        raise IncompatibleError, "baseline validation failed: #{errors.join('; ')}" unless errors.empty?

        File.rename(tmp, path)
        begin
          dir_fd = File.open(dir, "r")
          dir_fd.fsync
          dir_fd.close
        rescue StandardError
          nil
        end
      ensure
        File.unlink(tmp) if File.exist?(tmp)
      end
    end

    def self.read(path)
      unless File.file?(path)
        raise IncompatibleError, "baseline not found at #{path}"
      end
      raw = File.binread(path)
      begin
        data = JSON.parse(raw)
      rescue JSON::ParserError => error
        raise IncompatibleError, "baseline at #{path} is corrupted: #{error.message}; re-create with `railverdict baseline create`"
      end
      errors = SchemaValidator.validate_baseline(data)
      unless errors.empty?
        raise IncompatibleError, "baseline at #{path} is incompatible: #{errors.join('; ')}; re-create with `railverdict baseline create`"
      end
      fingerprints = data.fetch("entries").map { |entry| entry.fetch("fingerprint") }
      if fingerprints.uniq.length != fingerprints.length
        raise IncompatibleError, "baseline at #{path} contains duplicate fingerprints; re-create with `railverdict baseline create`"
      end
      new(data)
    end

    def self.read_optional(path)
      return nil unless File.file?(path)

      read(path)
    end

    def self.validate_hash(hash)
      errors = SchemaValidator.validate_baseline(hash)
      raise IncompatibleError, errors.join("; ") unless errors.empty?

      hash
    end
  end
end
