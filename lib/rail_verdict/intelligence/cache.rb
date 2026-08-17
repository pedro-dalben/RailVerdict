# frozen_string_literal: true

require "digest"
require "json"
require "tempfile"
require "fileutils"

module RailVerdict
  module Intelligence
    class Cache
      MAX_TOTAL_BYTES = 10 * 1024 * 1024

      def initialize(root:, enabled: false)
        @root = root.to_s
        @enabled = enabled
        @dir = File.join(@root, ".railverdict", "cache", "ai")
      end

      def enabled?
        @enabled
      end

      def key_for(fingerprint:, context_hash:, provider:, model:, prompt_version:, schema_version:)
        Digest::SHA256.hexdigest([fingerprint, context_hash, provider, model, prompt_version, schema_version].join("|"))
      end

      def read(key)
        return nil unless @enabled

        path = File.join(@dir, "#{key}.json")
        return nil unless File.file?(path)

        data = JSON.parse(File.read(path))
        AIAnalysis.from_hash(data)
      rescue StandardError
        nil
      end

      def write(key, analysis)
        return unless @enabled

        FileUtils.mkdir_p(@dir)
        path = File.join(@dir, "#{key}.json")
        tmp = Tempfile.new(["ai-cache", ".json"], @dir)
        begin
          tmp.write(JSON.generate(analysis.to_h))
          tmp.flush
          tmp.fsync
          File.chmod(0o600, tmp.path)
          File.rename(tmp.path, path)
          File.chmod(0o600, path) rescue nil
          enforce_size_limit
        ensure
          tmp.close rescue nil
          File.unlink(tmp.path) rescue nil
        end
      end

      private

      def enforce_size_limit
        files = Dir.glob(File.join(@dir, "*.json")).map { |p| [p, File.size(p)] }.sort_by { |_, s| s }
        total = files.sum { |_, s| s }
        files.each do |path, _|
          break if total <= MAX_TOTAL_BYTES

          size = File.size(path) rescue 0
          File.unlink(path) rescue nil
          total -= size
        end
      end
    end
  end
end
