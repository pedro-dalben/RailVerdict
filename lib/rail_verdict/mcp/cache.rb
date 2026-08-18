# frozen_string_literal: true

module RailVerdict
  module MCP
    class Cache
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
        file_sig = file_identity(effective_root)
        worktree_sig = worktree_identity(effective_root)
        {
          "config_digest" => config&.digest,
          "revision" => ctx&.revision,
          "findings_hash" => outcome.findings&.map(&:fingerprint)&.sort&.hash,
          "file_sig" => file_sig,
          "worktree_sig" => worktree_sig
        }
      end

      def file_identity(root)
        return nil unless root && File.directory?(root.to_s)

        begin
          baseline_path = File.join(File.realpath(root.to_s), ".railverdict-baseline.json")
          waiver_path = File.join(File.realpath(root.to_s), ".railverdict-waivers.json")
          {
            "baseline_mtime" => File.exist?(baseline_path) ? File.mtime(baseline_path).to_i : nil,
            "baseline_size" => File.exist?(baseline_path) ? File.size(baseline_path) : nil,
            "waiver_mtime" => File.exist?(waiver_path) ? File.mtime(waiver_path).to_i : nil,
            "waiver_size" => File.exist?(waiver_path) ? File.size(waiver_path) : nil,
            "config_mtime" => begin
              cfg = File.join(File.realpath(root.to_s), ".railverdict.yml")
              File.exist?(cfg) ? File.mtime(cfg).to_i : nil
            rescue StandardError
              nil
            end
          }
        rescue StandardError
          nil
        end
      end

      def worktree_identity(root)
        return nil unless root && File.directory?(root.to_s)

        begin
          real = File.realpath(root.to_s)
          out = IO.popen(["git", "-C", real, "status", "--porcelain", "-uall", "--no-renames"], err: [:child, :out]) { |io| io.read(64 * 1024) } rescue nil
          return nil if out.nil?

          out = out.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").strip
          return "clean" if out.empty?

          require "digest"
          Digest::SHA256.hexdigest(out)
        rescue StandardError
          nil
        end
      end
    end
  end
end
