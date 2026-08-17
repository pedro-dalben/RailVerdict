# frozen_string_literal: true

module RailVerdict
  module Intelligence
    class AIAnalysis
      SCHEMA_VERSION = "1.0"
      ASSESSMENTS = %w[likely_cause needs_investigation uncertain].freeze
      CONFIDENCES = %w[low medium high].freeze

      attr_reader :finding_id, :fingerprint, :assessment, :confidence, :summary,
                  :root_cause, :suggested_fix, :recommended_tests, :evidence_notes, :provenance

      def initialize(finding_id:, fingerprint:, assessment:, confidence:, summary:, provenance:,
                     root_cause: nil, suggested_fix: nil, recommended_tests: [], evidence_notes: [])
        @finding_id = finding_id.dup.freeze
        @fingerprint = fingerprint.dup.freeze
        @assessment = assessment.dup.freeze
        @confidence = confidence.dup.freeze
        @summary = summary.dup.freeze
        @root_cause = root_cause&.dup&.freeze
        @suggested_fix = suggested_fix&.dup&.freeze
        @recommended_tests = (recommended_tests || []).map { |v| v.dup.freeze }.freeze
        @evidence_notes = (evidence_notes || []).map { |v| v.dup.freeze }.freeze
        @provenance = deep_freeze(provenance.dup)
        validate!
        freeze
      end

      def to_h
        h = {
          "schema_version" => SCHEMA_VERSION,
          "finding_id" => finding_id,
          "fingerprint" => fingerprint,
          "assessment" => assessment,
          "confidence" => confidence,
          "summary" => summary,
          "provenance" => provenance
        }
        h["root_cause"] = root_cause if root_cause
        h["suggested_fix"] = suggested_fix if suggested_fix
        h["recommended_tests"] = recommended_tests unless recommended_tests.empty?
        h["evidence_notes"] = evidence_notes unless evidence_notes.empty?
        h
      end

      def self.from_hash(hash)
        errors = SchemaValidator.validate_ai_analysis(hash)
        raise ArgumentError, errors.join("; ") unless errors.empty?

        new(
          finding_id: hash.fetch("finding_id"),
          fingerprint: hash.fetch("fingerprint"),
          assessment: hash.fetch("assessment"),
          confidence: hash.fetch("confidence"),
          summary: hash.fetch("summary"),
          root_cause: hash["root_cause"],
          suggested_fix: hash["suggested_fix"],
          recommended_tests: hash["recommended_tests"] || [],
          evidence_notes: hash["evidence_notes"] || [],
          provenance: hash.fetch("provenance")
        )
      end

      private

      def validate!
        raise ArgumentError, "assessment must be one of #{ASSESSMENTS.join(', ')}" unless ASSESSMENTS.include?(assessment)
        raise ArgumentError, "confidence must be one of #{CONFIDENCES.join(', ')}" unless CONFIDENCES.include?(confidence)
        raise ArgumentError, "fingerprint invalid" unless fingerprint.match?(/\Asha256:[0-9a-f]{64}\z/)
      end

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
