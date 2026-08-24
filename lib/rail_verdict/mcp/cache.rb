# frozen_string_literal: true

require "digest"
require "pathname"
require "json"

require_relative "../canonical_json"
require_relative "../repository_state"

module RailVerdict
  module MCP
    class Cache
      MAX_STATUS_BYTES = 1 * 1024 * 1024
      MAX_DIRTY_FILES = 500
      MAX_STATE_FILE_BYTES = 2 * 1024 * 1024

      Entry = Struct.new(:outcome, :state_digest, :environment_digest, :receipt_document, :pr_intelligence_document, keyword_init: true)

      def initialize
        @mutex = Mutex.new
        @entry = nil
        @last_packets = {}
      end

      # Canonical storage: one guarded verification outcome plus its derived
      # machine contracts, keyed by the shared Repository State Identity.
      def store_verification(outcome:, receipt_document: nil, pr_intelligence_document: nil)
        state_digest = state_digest_for(outcome)
        environment_digest = environment_digest_for(outcome)
        @mutex.synchronize do
          @entry = Entry.new(
            outcome: outcome,
            state_digest: state_digest,
            environment_digest: environment_digest,
            receipt_document: receipt_document,
            pr_intelligence_document: pr_intelligence_document
          )
        end
        nil
      end

      # Returns the cached entry only when the CURRENT observable state still
      # matches the state that was verified. Never reruns analyzers.
      def fresh_entry(current_state)
        entry = @mutex.synchronize { @entry }
        return nil if entry.nil? || entry.state_digest.nil?
        return nil if current_state.nil? || !current_state.available?
        return nil if current_state.digest != entry.state_digest

        entry
      end

      def verification_state(current_state)
        entry = @mutex.synchronize { @entry }
        return "verification_required" if entry.nil? || entry.state_digest.nil?
        return "state_unavailable" if current_state.nil? || !current_state.available?
        return "stale" if current_state.digest != entry.state_digest

        "fresh"
      end

      # ---- compatibility surface (existing tools/tests) ----

      def store_outcome(outcome)
        store_verification(outcome: outcome)
        outcome
      end

      def fetch_outcome
        entry = @mutex.synchronize { @entry }
        entry&.outcome
      end

      def valid?
        entry = @mutex.synchronize { @entry }
        return false if entry.nil? || entry.state_digest.nil?

        current = current_state_for(entry.outcome)
        return false if current.nil? || !current.available?

        current.digest == entry.state_digest &&
          environment_digest_for(entry.outcome) == entry.environment_digest
      rescue StandardError
        false
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

      def state_digest_for(outcome)
        post = outcome.repository_state_post
        return post.digest if post.respond_to?(:available?) && post&.available?

        current_state_for(outcome)&.digest
      rescue StandardError
        nil
      end

      def current_state_for(outcome)
        root = outcome&.context&.repository_root
        root ||= outcome&.result&.git&.fetch("repository_root", nil) rescue nil
        return nil unless root.is_a?(String) && File.directory?(root)

        real = begin
          File.realpath(root)
        rescue StandardError
          return nil
        end
        RepositoryState.capture(repository_root: real, configuration_paths: configuration_paths_for(outcome, real))
      rescue StandardError
        nil
      end

      def configuration_paths_for(outcome, real)
        config = outcome&.configuration
        {
          config: config&.source_path || File.join(real, ".railverdict.yml"),
          baseline: config ? Baseline.resolve_path(repository_root: real, configuration: config) : File.join(real, ".railverdict-baseline.json"),
          waivers: config ? WaiverStore.resolve_path(repository_root: real, configuration: config) : File.join(real, ".railverdict-waivers.json")
        }
      rescue StandardError
        {
          config: File.join(real, ".railverdict.yml"),
          baseline: File.join(real, ".railverdict-baseline.json"),
          waivers: File.join(real, ".railverdict-waivers.json")
        }
      end

      def environment_digest_for(outcome)
        payload = {
          "railverdict_version" => RailVerdict::VERSION,
          "ruby_version" => RUBY_VERSION,
          "analyzer_versions" => sorted_analyzer_versions(outcome)
        }
        Digest::SHA256.hexdigest(CanonicalJSON.generate(payload))
      end

      def sorted_analyzer_versions(outcome)
        versions = outcome&.context&.analyzer_versions
        versions = {} unless versions.is_a?(Hash)
        canonical = {}
        versions.each { |k, v| canonical[k.to_s] = RailVerdict::Analyzers::Shared.canonical_tool_version(v) }
        canonical.sort.to_h
      rescue StandardError
        {}
      end
    end
  end
end
