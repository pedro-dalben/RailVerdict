# frozen_string_literal: true

require "digest"
require "json"

module RailVerdict
  module Repair
    class Packet
      SCHEMA_VERSION = "1.0"
      PACKET_ID_PATTERN = /\Asha256:[0-9a-f]{64}\z/

      def self.packet_id_for(fingerprint:, source_revision:, base_revision:, configuration_digest:, baseline_digest:, analyzer_versions:)
        payload = {
          "packet_schema_version" => SCHEMA_VERSION,
          "fingerprint" => fingerprint,
          "source_revision" => source_revision,
          "base_revision" => base_revision,
          "configuration_digest" => configuration_digest,
          "baseline_digest" => baseline_digest,
          "analyzer_versions" => (analyzer_versions || {}).sort.to_h
        }
        sorted = payload.keys.sort.to_h { |k| [k, payload[k]] }
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(sorted))}"
      end

      def self.validate_hash(hash)
        errors = SchemaValidator.validate_repair_packet(hash)
        raise ArgumentError, "invalid repair packet: #{errors.join('; ')}" unless errors.empty?

        hash
      end

      attr_reader :packet_id, :created_at, :railverdict_version, :source_revision,
                  :base_revision, :merge_base, :target, :verification, :evidence,
                  :git_context, :diff_context, :rails_context, :source_context,
                  :policy, :baseline_state, :waivers_state, :ai_analysis,
                  :verification_plan, :constraints, :instructions, :completeness,
                  :success_criteria, :boundary

      def initialize(**kwargs)
        @packet_id = kwargs.fetch(:packet_id).dup.freeze
        @created_at = kwargs.fetch(:created_at).dup.freeze
        @railverdict_version = kwargs.fetch(:railverdict_version).dup.freeze
        @source_revision = kwargs[:source_revision]&.dup&.freeze
        @base_revision = kwargs[:base_revision]&.dup&.freeze
        @merge_base = kwargs[:merge_base]&.dup&.freeze
        @target = deep_freeze(kwargs.fetch(:target))
        @verification = deep_freeze(kwargs.fetch(:verification))
        @evidence = deep_freeze(kwargs.fetch(:evidence))
        @git_context = deep_freeze(kwargs.fetch(:git_context))
        @diff_context = deep_freeze(kwargs.fetch(:diff_context) { { "hunk" => "", "truncated" => false } })
        @rails_context = deep_freeze(kwargs.fetch(:rails_context))
        @source_context = deep_freeze(kwargs.fetch(:source_context))
        @policy = deep_freeze(kwargs.fetch(:policy))
        @baseline_state = deep_freeze(kwargs.fetch(:baseline_state))
        @waivers_state = deep_freeze(kwargs.fetch(:waivers_state))
        @ai_analysis = kwargs[:ai_analysis] ? deep_freeze(kwargs[:ai_analysis]) : nil
        @verification_plan = deep_freeze(kwargs.fetch(:verification_plan))
        @constraints = deep_freeze(kwargs.fetch(:constraints))
        @instructions = (kwargs[:instructions] || []).map(&:dup).map(&:freeze).freeze
        @completeness = deep_freeze(kwargs.fetch(:completeness))
        @success_criteria = deep_freeze(kwargs.fetch(:success_criteria))
        @boundary = deep_freeze(kwargs.fetch(:boundary))
        validate!
        freeze
      end

      def to_h
        h = {
          "schema_version" => SCHEMA_VERSION,
          "packet_id" => packet_id,
          "created_at" => created_at,
          "railverdict_version" => railverdict_version,
          "source_revision" => source_revision,
          "target" => target,
          "verification" => verification,
          "evidence" => evidence,
          "git_context" => git_context,
          "rails_context" => rails_context,
          "source_context" => source_context,
          "policy" => policy,
          "baseline_state" => baseline_state,
          "waivers_state" => waivers_state,
          "verification_plan" => verification_plan,
          "constraints" => constraints,
          "completeness" => completeness,
          "success_criteria" => success_criteria,
          "boundary" => boundary
        }
        h["base_revision"] = base_revision unless base_revision.nil?
        h["merge_base"] = merge_base unless merge_base.nil?
        h["diff_context"] = diff_context if diff_context
        h["ai_analysis"] = ai_analysis if ai_analysis
        h["instructions"] = instructions unless instructions.empty?
        h
      end

      def to_json(*args)
        JSON.generate(to_h, *args)
      end

      private

      def validate!
        raise ArgumentError, "packet_id invalid" unless packet_id.match?(PACKET_ID_PATTERN)

        errors = SchemaValidator.validate_repair_packet(to_h_without_validation)
        raise ArgumentError, "invalid repair packet: #{errors.join('; ')}" unless errors.empty?
      end

      def to_h_without_validation
        h = {
          "schema_version" => SCHEMA_VERSION,
          "packet_id" => packet_id,
          "created_at" => created_at,
          "railverdict_version" => railverdict_version,
          "source_revision" => source_revision,
          "target" => target,
          "verification" => verification,
          "evidence" => evidence,
          "git_context" => git_context,
          "rails_context" => rails_context,
          "source_context" => source_context,
          "policy" => policy,
          "baseline_state" => baseline_state,
          "waivers_state" => waivers_state,
          "verification_plan" => verification_plan,
          "constraints" => constraints,
          "completeness" => completeness,
          "success_criteria" => success_criteria,
          "boundary" => boundary
        }
        h["base_revision"] = base_revision unless base_revision.nil?
        h["merge_base"] = merge_base unless merge_base.nil?
        h["diff_context"] = diff_context if diff_context
        h["ai_analysis"] = ai_analysis if ai_analysis
        h["instructions"] = instructions unless instructions.empty?
        h
      end

      def deep_freeze(value)
        case value
        when Hash
          value.each { |k, v| k.freeze if k.is_a?(String); deep_freeze(v) }
          value.freeze
        when Array
          value.each { |v| deep_freeze(v) }
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
end
