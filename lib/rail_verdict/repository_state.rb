# frozen_string_literal: true

require "digest"
require "json"

require_relative "canonical_json"
require_relative "process_runner"

module RailVerdict
  class RepositoryState
    SCHEMA_VERSION = "1"
    MAX_INDEX_BYTES = 8 * 1024 * 1024
    MAX_STATUS_BYTES = 4 * 1024 * 1024
    MAX_DIRTY_PATHS = 500
    MAX_FILE_BYTES = 2 * 1024 * 1024
    UNBORN_HEAD = "unborn"

    class UnavailableError < RailVerdict::Error
      attr_reader :reason

      def initialize(reason, detail: nil)
        super(detail ? "#{reason}: #{detail}" : reason.to_s)
        @reason = reason.to_s
      end
    end

    attr_reader :projection, :unavailable_reason, :dirty_paths_count

    def self.capture(repository_root:, runner: ProcessRunner, configuration_paths: nil)
      root = File.realpath(repository_root)
      paths = resolve_configuration_paths(root, configuration_paths)

      head = capture_head(root, runner: runner)
      index_digest = capture_index_digest(root, runner: runner)
      worktree = capture_worktree(root, runner: runner)
      configuration_digest = file_content_identity(paths.fetch(:config))
      baseline_digest = optional_file_digest(paths.fetch(:baseline))
      waivers_digest = optional_file_digest(paths.fetch(:waivers))

      components = {
        "head" => head,
        "index_digest" => index_digest,
        "worktree_digest" => worktree.fetch("digest"),
        "configuration_digest" => configuration_digest,
        "baseline_digest" => baseline_digest,
        "waivers_digest" => waivers_digest
      }
      digest = "sha256:#{Digest::SHA256.hexdigest(CanonicalJSON.generate(components))}"
      projection = {
        "schema_version" => SCHEMA_VERSION,
        "digest" => digest,
        "components" => components
      }
      new(projection: projection, dirty_paths_count: worktree.fetch("dirty_paths_count"))
    rescue UnavailableError => error
      unavailable(error.reason)
    rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR
      unavailable(:repository_root_unavailable)
    end

    def self.resolve_configuration_paths(root, overrides)
      {
        config: absolute_path(overrides && overrides[:config], File.join(root, ".railverdict.yml"), root),
        baseline: absolute_path(overrides && overrides[:baseline], File.join(root, ".railverdict-baseline.json"), root),
        waivers: absolute_path(overrides && overrides[:waivers], File.join(root, ".railverdict-waivers.json"), root)
      }
    end
    private_class_method :resolve_configuration_paths

    def self.absolute_path(override, default, root)
      return default if override.nil? || override.to_s.strip.empty?

      path = override.to_s
      Pathname.new(path).absolute? ? path : File.expand_path(path, root)
    end
    private_class_method :absolute_path

    def self.capture_head(root, runner:)
      inside = runner.run("git", ["rev-parse", "--is-inside-work-tree"], chdir: root, timeout_seconds: 5.0)
      return nil unless inside.status == :exited && inside.exit_code == 0 && inside.stdout.to_s.strip == "true"

      result = runner.run("git", ["rev-parse", "-q", "--verify", "HEAD"], chdir: root, timeout_seconds: 5.0)
      if result.status == :exited && result.exit_code.zero?
        sha = result.stdout.to_s.strip
        return sha if sha.match?(/\A[0-9a-f]{7,64}\z/)

        raise UnavailableError.new(:invalid_head_output, detail: sha.inspect)
      end
      unborn = result.status == :exited && result.exit_code == 1 && result.stdout.to_s.strip.empty?
      return UNBORN_HEAD if unborn

      raise UnavailableError.new(:git_unavailable, detail: "cannot resolve HEAD")
    end
    private_class_method :capture_head

    def self.capture_index_digest(root, runner:)
      result = runner.run("git", ["ls-files", "-s", "-z"], chdir: root, timeout_seconds: 10.0, max_stdout_bytes: MAX_INDEX_BYTES, binary_output: true)
      unless result.status == :exited && result.exit_code.zero?
        raise UnavailableError.new(:git_unavailable, detail: "cannot read the Git index")
      end
      raise UnavailableError.new(:index_truncated) if result.stdout_truncated

      prefixed(Digest::SHA256.hexdigest(result.stdout.bytesize.zero? ? String.new(encoding: Encoding::BINARY) : result.stdout.dup.force_encoding(Encoding::BINARY)))
    end
    private_class_method :capture_index_digest

    def self.capture_worktree(root, runner:)
      result = runner.run(
        "git",
        ["status", "--porcelain=v2", "--no-renames", "-z", "--untracked-files=all"],
        chdir: root,
        timeout_seconds: 10.0,
        max_stdout_bytes: MAX_STATUS_BYTES,
        binary_output: true
      )
      unless result.status == :exited && result.exit_code.zero?
        raise UnavailableError.new(:git_unavailable, detail: "cannot read the worktree status")
      end
      raise UnavailableError.new(:status_truncated) if result.stdout_truncated

      entries = parse_status_v2(result.stdout.bytesize.zero? ? String.new(encoding: Encoding::BINARY) : result.stdout.dup.force_encoding(Encoding::BINARY))
      # Keep only the WORKTREE-vs-INDEX delta (plus untracked): staged-only
      # changes are fully covered by the index snapshot identity.
      entries = entries.reject { |entry| entry["xy"] != "??" && entry.fetch("xy").to_s[1] == "." }
      raise UnavailableError.new(:too_many_dirty_paths) if entries.length > MAX_DIRTY_PATHS

      hashed = entries.map { |entry| entry_content_identity(root, entry) }
      sorted = hashed.sort_by { |item| [item["path"], item["xy"]] }
      {
        "digest" => prefixed(Digest::SHA256.hexdigest(CanonicalJSON.generate({ "entries" => sorted }))),
        "dirty_paths_count" => sorted.length
      }
    end
    private_class_method :capture_worktree

    def self.parse_status_v2(raw)
      records = raw.split("\0", -1)
      records.pop if records.last == ""
      records.filter_map do |record|
        next if record.empty?

        kind = record[0, 1]
        case kind
        when "?"
          {"xy" => "??", "path" => record[2..].to_s}
        when "1"
          parts = record.split(" ", 9)
          raise UnavailableError.new(:invalid_status_output, detail: record.inspect) if parts.length < 9

          {"xy" => parts[1], "path" => parts[8]}
        when "u"
          parts = record.split(" ", 11)
          raise UnavailableError.new(:invalid_status_output, detail: record.inspect) if parts.length < 11

          {"xy" => parts[1], "path" => parts[10]}
        when "2"
          parts = record.split(" ", 11)
          raise UnavailableError.new(:invalid_status_output, detail: record.inspect) if parts.length < 11

          {"xy" => parts[1], "path" => parts[10]}
        else
          raise UnavailableError.new(:invalid_status_output, detail: record[0, 32].inspect)
        end
      end
    end
    private_class_method :parse_status_v2

    def self.entry_content_identity(root, entry)
      path = entry.fetch("path")
      full = File.join(root, path)
      identity = nil
      if File.symlink?(full)
        begin
          identity = {"kind" => "symlink", "sha256" => Digest::SHA256.hexdigest(File.readlink(full))}
        rescue StandardError
          raise UnavailableError.new(:file_unreadable, detail: path)
        end
      elsif !File.exist?(full)
        identity = {"kind" => "deleted"}
      elsif File.directory?(full)
        identity = {"kind" => "directory"}
      elsif !File.file?(full)
        identity = {"kind" => "type_changed"}
      else
        size = begin
          File.size(full)
        rescue StandardError
          raise UnavailableError.new(:file_unreadable, detail: path)
        end
        raise UnavailableError.new(:file_too_large, detail: path) if size > MAX_FILE_BYTES

        content = begin
          File.binread(full)
        rescue StandardError
          raise UnavailableError.new(:file_unreadable, detail: path)
        end
        identity = {"kind" => "file", "sha256" => Digest::SHA256.hexdigest(content)}
      end
      entry.merge(identity)
    end
    private_class_method :entry_content_identity

    def self.file_content_identity(path)
      unless File.file?(path)
        raise UnavailableError.new(:configuration_unreadable, detail: path.to_s)
      end

      size = File.size(path)
      raise UnavailableError.new(:file_too_large, detail: path.to_s) if size > MAX_FILE_BYTES

      prefixed(Digest::SHA256.hexdigest(File.binread(path)))
    rescue StandardError => error
      raise error if error.is_a?(UnavailableError)

      raise UnavailableError.new(:configuration_unreadable, detail: path.to_s)
    end
    private_class_method :file_content_identity

    def self.optional_file_digest(path)
      return nil unless File.file?(path)

      size = File.size(path)
      raise UnavailableError.new(:file_too_large, detail: path.to_s) if size > MAX_FILE_BYTES

      prefixed(Digest::SHA256.hexdigest(File.binread(path)))
    rescue UnavailableError
      raise
    rescue StandardError
      raise UnavailableError.new(:file_unreadable, detail: path.to_s)
    end
    private_class_method :optional_file_digest

    def self.prefixed(hex)
      "sha256:#{hex}"
    end
    private_class_method :prefixed

    def self.unavailable(reason)
      new(projection: nil, unavailable_reason: reason.to_s, dirty_paths_count: nil)
    end

    def initialize(projection:, unavailable_reason: nil, dirty_paths_count: nil)
      @projection = projection&.freeze
      @unavailable_reason = unavailable_reason&.to_s&.freeze
      @dirty_paths_count = dirty_paths_count
      freeze
    end

    def available?
      !@projection.nil?
    end

    def digest
      available? ? @projection.fetch("digest") : nil
    end

    def components
      available? ? @projection.fetch("components") : nil
    end

    def raise_unavailable!(context: "repository state")
      return self if available?

      raise UnavailableError.new(@unavailable_reason, detail: context)
    end
  end
end
