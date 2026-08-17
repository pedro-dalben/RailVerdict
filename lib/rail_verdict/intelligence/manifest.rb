# frozen_string_literal: true

require "digest"
require "json"

module RailVerdict
  module Intelligence
    class Manifest
      attr_reader :finding_id, :fingerprint, :finding, :snippets, :rails_facts,
                  :git_slice, :comparison_slice, :policy_reason

      def initialize(finding_id:, fingerprint:, finding:, snippets:, rails_facts:, git_slice:, comparison_slice:, policy_reason:)
        @finding_id = finding_id.dup.freeze
        @fingerprint = fingerprint.dup.freeze
        @finding = deep_freeze(finding.dup)
        @snippets = deep_freeze(snippets.map(&:dup))
        @rails_facts = deep_freeze(rails_facts)
        @git_slice = deep_freeze(git_slice)
        @comparison_slice = deep_freeze(comparison_slice)
        @policy_reason = policy_reason&.dup&.freeze
        freeze
      end

      def to_h
        {
          finding_id: finding_id,
          fingerprint: fingerprint,
          finding: finding,
          snippets: snippets,
          rails_facts: rails_facts,
          git_slice: git_slice,
          comparison_slice: comparison_slice,
          policy_reason: policy_reason
        }
      end

      def to_json_hash
        {
          "finding_id" => finding_id,
          "fingerprint" => fingerprint,
          "finding" => finding,
          "snippets" => snippets,
          "rails_facts" => rails_facts,
          "git_slice" => git_slice,
          "comparison_slice" => comparison_slice,
          "policy_reason" => policy_reason
        }
      end

      def context_hash
        Digest::SHA256.hexdigest(JSON.generate(to_json_hash.sort.to_h))
      end

      def total_bytes
        JSON.generate(to_json_hash).bytesize
      end

      private

      def deep_freeze(value)
        case value
        when Hash then value.each { |k, v| k.freeze if k.is_a?(String); deep_freeze(v) }; value.freeze
        when Array then value.each { |v| deep_freeze(v) }; value.freeze
        when String then value.freeze
        else value
        end
      end
    end
  end
end
