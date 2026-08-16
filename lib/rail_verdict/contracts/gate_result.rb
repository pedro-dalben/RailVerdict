# frozen_string_literal: true

module RailVerdict
  class GateResult
    SCHEMA_VERSION = "1.0"
    COMPLETION_STATUSES = %w[complete incomplete interrupted].freeze
    GATES = %w[PASS WARN FAIL INCOMPLETE].freeze
    POLICY_STATUSES = %w[pass warn fail not_evaluated].freeze
    FAILURE_CODES = %w[
      unavailable unsupported timed_out signaled failed parse_failed truncated
      malformed configuration interrupted
    ].freeze

    attr_reader :completion_status, :gate, :policy_status, :findings,
                :analyzer_results, :operational_failures, :decision_reasons

    def initialize(completion_status:, gate:, policy_status:, findings:, analyzer_results:,
                   operational_failures:, decision_reasons:)
      @completion_status = require_member(completion_status, COMPLETION_STATUSES, "completion_status")
      @gate = require_member(gate, GATES, "gate")
      @policy_status = require_member(policy_status, POLICY_STATUSES, "policy_status")
      @findings = validate_findings(findings)
      @analyzer_results = validate_analyzer_results(analyzer_results)
      @operational_failures = validate_operational_failures(operational_failures)
      @decision_reasons = validate_decision_reasons(decision_reasons)
      enforce_state_coupling
      freeze
    end

    def complete?
      completion_status == "complete"
    end

    def incomplete?
      completion_status != "complete"
    end

    def to_schema_h
      {
        "schema_version" => SCHEMA_VERSION,
        "completion_status" => completion_status,
        "gate" => gate,
        "policy_status" => policy_status,
        "findings" => findings,
        "analyzer_results" => analyzer_results.map(&:to_schema_h),
        "operational_failures" => operational_failures,
        "decision_reasons" => decision_reasons
      }
    end

    private

    def require_member(value, allowed, name)
      raise ArgumentError, "#{name} must be one of #{allowed.join(', ')}" unless allowed.include?(value)

      value
    end

    def enforce_state_coupling
      if completion_status == "complete"
        unless %w[PASS WARN FAIL].include?(gate) && %w[pass warn fail].include?(policy_status)
          raise ArgumentError, "complete result must contain a completed gate and policy status"
        end
      elsif gate != "INCOMPLETE" || policy_status != "not_evaluated" || operational_failures.empty?
        raise ArgumentError, "incomplete result must be INCOMPLETE, not_evaluated, and explain a failure"
      end
    end

    def validate_findings(findings)
      unless findings.is_a?(Array)
        raise ArgumentError, "findings must be an array"
      end

      findings.map do |finding|
        raise ArgumentError, "finding summary must be a Hash" unless finding.is_a?(Hash)

        expected = %w[id fingerprint severity state blocking]
        raise ArgumentError, "finding summary contains unknown fields" unless finding.keys == expected
        raise ArgumentError, "finding summary id is invalid" unless finding["id"].is_a?(String) && !finding["id"].empty?
        raise ArgumentError, "finding summary fingerprint is invalid" unless finding["fingerprint"].match?(/\Asha256:[0-9a-f]{64}\z/)
        raise ArgumentError, "finding summary severity is invalid" unless Finding::SEVERITIES.include?(finding["severity"])
        raise ArgumentError, "finding summary state is invalid" unless Finding::STATES.include?(finding["state"])
        raise ArgumentError, "finding summary blocking must be boolean" unless [true, false].include?(finding["blocking"])

        finding.dup.freeze
      end.freeze
    end

    def validate_analyzer_results(results)
      raise ArgumentError, "analyzer_results must be an array" unless results.is_a?(Array)
      raise ArgumentError, "analyzer_results must contain AnalyzerResult values" unless results.all? { |result| result.is_a?(AnalyzerResult) }

      results.sort_by(&:analyzer).freeze
    end

    def validate_operational_failures(failures)
      raise ArgumentError, "operational_failures must be an array" unless failures.is_a?(Array)

      failures.map do |failure|
        raise ArgumentError, "operational failure must be a Hash" unless failure.is_a?(Hash)
        allowed = %w[code analyzer message]
        raise ArgumentError, "operational failure contains unknown fields" unless (failure.keys - allowed).empty?
        raise ArgumentError, "operational failure has invalid code" unless FAILURE_CODES.include?(failure["code"])
        raise ArgumentError, "operational failure requires a message" unless failure["message"].is_a?(String) && !failure["message"].empty?
        if failure.key?("analyzer") && !failure["analyzer"].is_a?(String)
          raise ArgumentError, "operational failure analyzer must be a string"
        end

        failure.dup.freeze
      end.freeze
    end

    def validate_decision_reasons(reasons)
      raise ArgumentError, "decision_reasons must be an array" unless reasons.is_a?(Array)

      reasons.map do |reason|
        raise ArgumentError, "decision reason must be a Hash" unless reason.is_a?(Hash)
        raise ArgumentError, "decision reason fields are invalid" unless reason.keys == %w[code message]
        raise ArgumentError, "decision reason code is invalid" unless reason["code"].is_a?(String) && !reason["code"].empty?
        raise ArgumentError, "decision reason message is invalid" unless reason["message"].is_a?(String) && !reason["message"].empty?

        reason.dup.freeze
      end.freeze
    end
  end
end
