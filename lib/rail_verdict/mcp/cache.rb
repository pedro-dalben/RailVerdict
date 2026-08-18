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
        root = outcome.context&.repository_root || outcome.result&.git&.fetch("repository_root", nil)
        file_sig = nil
        if root && File.directory?(root.to_s)
          begin
            baseline_path = File.join(File.realpath(root.to_s), ".railverdict-baseline.json")
            waiver_path = File.join(File.realpath(root.to_s), ".railverdict-waivers.json")
            file_sig = {
              "baseline_mtime" => File.exist?(baseline_path) ? File.mtime(baseline_path).to_i : nil,
              "baseline_size" => File.exist?(baseline_path) ? File.size(baseline_path) : nil,
              "waiver_mtime" => File.exist?(waiver_path) ? File.mtime(waiver_path).to_i : nil,
              "waiver_size" => File.exist?(waiver_path) ? File.size(waiver_path) : nil
            }
          rescue StandardError
            file_sig = nil
          end
        end
        {
          "config_digest" => config&.digest,
          "revision" => ctx&.revision,
          "findings_hash" => outcome.findings&.map(&:fingerprint)&.sort&.hash,
          "file_sig" => file_sig
        }
      end
    end
  end
end
