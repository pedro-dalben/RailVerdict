# frozen_string_literal: true

require "digest"
require "pathname"

module RailVerdict
  module MCP
    class Cache
      MAX_STATUS_BYTES = 1 * 1024 * 1024
      MAX_DIRTY_FILES = 500
      MAX_STATE_FILE_BYTES = 2 * 1024 * 1024

      def initialize
        @mutex = Mutex.new
        @last_outcome = nil
        @last_digests = nil
        @last_packets = {}
      end

      def store_outcome(outcome)
        @mutex.synchronize do
          @last_outcome = outcome
          @last_digests = digests_for(outcome)
        end
      end

      def fetch_outcome
        @mutex.synchronize { @last_outcome }
      end

      def valid?
        @mutex.synchronize { valid_unsynchronized? }
      end

      def stale?
        !valid?
      end

      def store_packet(packet_hash)
        @mutex.synchronize do
          @last_packets[packet_hash["packet_id"]] = packet_hash
          if @last_packets.size > 10
            oldest = @last_packets.keys.first
            @last_packets.delete(oldest)
          end
        end
      end

      def fetch_packet(packet_id)
        @mutex.synchronize { @last_packets[packet_id] }
      end

      private

      def valid_unsynchronized?
        return false if @last_outcome.nil? || @last_digests.nil?

        current = digests_for(@last_outcome)
        return false if current.nil? || current["unavailable"]

        current == @last_digests
      rescue StandardError
        false
      end

      def digests_for(outcome)
        return nil unless outcome

        ctx = outcome.context
        config = outcome.configuration
        root = outcome.context&.repository_root
        root ||= outcome.result&.git&.fetch("repository_root", nil) rescue nil
        root ||= @last_outcome&.context&.repository_root rescue nil
        if root.nil? && @last_outcome
          root = @last_outcome.context&.repository_root rescue nil
        end
        stored_root = @last_outcome&.context&.repository_root rescue nil
        effective_root = root || stored_root

        file_sig = file_identity(effective_root, config)
        wt = worktree_identity(effective_root)
        if wt && wt["unavailable"]
          return { "unavailable" => true }
        end

        {
          "config_digest" => config&.digest,
          "revision" => ctx&.revision,
          "findings_hash" => outcome.findings&.map(&:fingerprint)&.sort&.hash,
          "file_sig" => file_sig,
          "worktree" => wt
        }
      end

      def file_identity(root, config)
        return nil unless root && File.directory?(root.to_s)

        begin
          real = File.realpath(root.to_s)
          paths = {}
          paths["config"] = File.join(real, ".railverdict.yml")
          baseline_override = config.respond_to?(:baseline_path) ? config.baseline_path : nil
          paths["baseline"] = resolve_state_path(root: real, override: baseline_override, default: ".railverdict-baseline.json", config_path: nil)
          waiver_override = config.respond_to?(:waivers_path) ? config.waivers_path : nil
          paths["waivers"] = resolve_state_path(root: real, override: waiver_override, default: ".railverdict-waivers.json", config_path: nil)

          result = {}
          paths.each do |key, path|
            result[key] = content_identity(path)
          end
          result
        rescue StandardError
          { "unavailable" => true }
        end
      end

      def resolve_state_path(root:, override:, default:, config_path:)
        if override && !override.to_s.strip.empty?
          p = override.to_s
          return Pathname.new(p).absolute? ? p : File.expand_path(p, root)
        end
        if config_path && !config_path.to_s.strip.empty?
          p = config_path.to_s
          return Pathname.new(p).absolute? ? p : File.expand_path(p, root)
        end
        File.join(root, default)
      end

      def content_identity(path)
        return { "state" => "missing" } unless File.exist?(path)
        return { "state" => "unavailable" } unless File.file?(path)

        begin
          size = File.size(path)
          return { "state" => "unavailable" } if size > MAX_STATE_FILE_BYTES

          content = File.binread(path)
          { "state" => "present", "sha256" => Digest::SHA256.hexdigest(content), "size" => size }
        rescue StandardError
          { "state" => "unavailable" }
        end
      end

      def worktree_identity(root)
        return nil unless root && File.directory?(root.to_s)

        begin
          real = File.realpath(root.to_s)
          status_result = ProcessRunner.run("git", ["status", "--porcelain=v1", "-z", "-uall", "--no-renames"], chdir: real, timeout_seconds: 5.0, max_stdout_bytes: MAX_STATUS_BYTES)
          if status_result.status == :timed_out || status_result.stdout_truncated || status_result.status == :spawn_failed
            return { "unavailable" => true }
          end
          if status_result.status != :exited || status_result.exit_code != 0
            return { "unavailable" => true }
          end

          raw = status_result.stdout.dup.force_encoding(Encoding::BINARY)
          entries = parse_status_z(raw)
          return { "clean" => true } if entries.empty?
          return { "unavailable" => true } if entries.length > MAX_DIRTY_FILES

          # Resolve HEAD for identity
          head = nil
          hr = ProcessRunner.run("git", ["rev-parse", "HEAD"], chdir: real, timeout_seconds: 3.0)
          if hr.status == :exited && hr.exit_code == 0
            head = hr.stdout.to_s.strip
          else
            return { "unavailable" => true }
          end

          hashed = entries.map do |entry|
            xy = entry[:xy]
            path = entry[:path]
            full = File.join(real, path)
            # Determine sentinel vs content hash
            if !File.exist?(full)
              { "xy" => xy, "path" => path, "kind" => "deleted" }
            elsif File.directory?(full)
              { "xy" => xy, "path" => path, "kind" => "directory" }
            elsif File.symlink?(full)
              begin
                target = File.readlink(full)
                { "xy" => xy, "path" => path, "kind" => "symlink", "sha256" => Digest::SHA256.hexdigest(target) }
              rescue StandardError
                { "xy" => xy, "path" => path, "kind" => "unavailable" }
              end
            elsif !File.file?(full)
              { "xy" => xy, "path" => path, "kind" => "type_changed" }
            else
              begin
                size = File.size(full)
                if size > MAX_STATE_FILE_BYTES
                  return { "unavailable" => true }
                end

                content = File.binread(full)
                { "xy" => xy, "path" => path, "kind" => "file", "sha256" => Digest::SHA256.hexdigest(content) }
              rescue StandardError
                return { "unavailable" => true }
              end
            end
          end

          sorted = hashed.sort_by { |h| [h["path"], h["xy"]] }
          canonical = JSON.generate({ "head" => head, "entries" => sorted })
          { "digest" => Digest::SHA256.hexdigest(canonical) }
        rescue StandardError
          { "unavailable" => true }
        end
      end

      def parse_status_z(raw)
        return [] if raw.nil? || raw.empty?

        parts = raw.split("\0")
        entries = []
        parts.each do |part|
          next if part.empty?

          # Format: XY SP path  (or XY SP path for renames, but --no-renames so no second path)
          # XY is 2 chars, then space, then path
          next if part.bytesize < 3

          xy = part[0, 2].force_encoding(Encoding::UTF_8)
          path = part[3..].to_s.dup.force_encoding(Encoding::UTF_8)
          # NUL-safe: path already split on NUL, keep as-is
          entries << { xy: xy, path: path }
        end
        entries
      end
    end
  end
end
