# frozen_string_literal: true

module RailVerdict
  class AnalyzerResult
    EXECUTION_STATUSES = %w[
      succeeded unavailable unsupported timed_out signaled
      failed parse_failed truncated malformed
    ].freeze
    FAILURE_CODES = (EXECUTION_STATUSES - ["succeeded"]).freeze
    EVIDENCE_STATUSES = %w[complete incomplete].freeze

    attr_reader :analyzer, :invocation, :tool_version, :execution_status,
                :evidence_status, :finding_ids, :failure, :evidence_summary

    def initialize(analyzer:, invocation:, execution_status:, finding_ids:, tool_version: nil, failure: nil, evidence_summary: nil)
      @analyzer = require_nonempty_string(analyzer, "analyzer", 256).freeze
      @invocation = validate_invocation(invocation)
      @execution_status = validate_execution_status(execution_status)
      @evidence_status = execution_status == "succeeded" ? "complete" : "incomplete"
      @tool_version = tool_version && require_nonempty_string(tool_version, "tool_version", 128).freeze
      @finding_ids = validate_finding_ids(finding_ids)
      @failure = validate_failure(failure)
      @evidence_summary = validate_evidence_summary(evidence_summary)
      enforce_coupling
      freeze
    end

    def complete?
      evidence_status == "complete"
    end

    def to_schema_h
      result = {}
      result["analyzer"] = analyzer
      result["tool_version"] = tool_version if tool_version
      result["invocation"] = invocation
      result["execution_status"] = execution_status
      result["evidence_status"] = evidence_status
      result["finding_ids"] = finding_ids
      result["failure"] = failure if failure
      result["evidence_summary"] = evidence_summary if evidence_summary
      result
    end

    private

    def enforce_coupling
      if execution_status == "succeeded"
        raise ArgumentError, "succeeded results cannot carry failure metadata" unless failure.nil?
      else
        raise ArgumentError, "non-succeeded results require failure metadata" if failure.nil?
        unless failure["code"] == execution_status
          raise ArgumentError, "failure code must match execution status"
        end
      end
    end

    def validate_invocation(invocation)
      raise ArgumentError, "invocation must be a Hash" unless invocation.is_a?(Hash)

      executable = invocation["executable"]
      argv = invocation["argv"]
      unless executable.is_a?(String) && !executable.empty? && executable.bytesize <= 1024
        raise ArgumentError, "invocation.executable must be a non-empty string"
      end
      unless argv.is_a?(Array) && argv.all? { |element| element.is_a?(String) && element.bytesize <= 4096 }
        raise ArgumentError, "invocation.argv must be an array of strings"
      end

      { "executable" => executable.dup.freeze, "argv" => argv.map(&:dup).map(&:freeze).freeze }.freeze
    end

    def validate_execution_status(value)
      unless EXECUTION_STATUSES.include?(value)
        raise ArgumentError, "execution_status must be one of #{EXECUTION_STATUSES.join(', ')}"
      end

      value
    end

    def validate_finding_ids(finding_ids)
      unless finding_ids.is_a?(Array) &&
             finding_ids.all? { |id| id.is_a?(String) && !id.empty? && id.bytesize <= 256 }
        raise ArgumentError, "finding_ids must be an array of non-empty strings"
      end

      finding_ids.map { |id| id.dup.freeze }.freeze
    end

    def validate_failure(failure)
      return nil if failure.nil?

      raise ArgumentError, "failure must be a Hash" unless failure.is_a?(Hash)

      code = failure["code"]
      message = failure["message"]
      unless FAILURE_CODES.include?(code)
        raise ArgumentError, "failure.code must be one of #{FAILURE_CODES.join(', ')}"
      end
      unless message.is_a?(String) && !message.empty? && message.bytesize <= 4096
        raise ArgumentError, "failure.message must be a non-empty string"
      end

      { "code" => code.freeze, "message" => message.dup.freeze }.freeze
    end

    def validate_evidence_summary(value)
      return nil if value.nil?

      raise ArgumentError, "evidence_summary must be a Hash" unless value.is_a?(Hash)
      raise ArgumentError, "evidence_summary is too large" if value.keys.length > 30

      value.each do |key, entry|
        raise ArgumentError, "evidence_summary keys must be non-empty strings" unless key.is_a?(String) && !key.empty? && key.bytesize <= 128
        if entry.is_a?(Hash) || entry.is_a?(Array)
          raise ArgumentError, "evidence_summary values must be primitives" unless key.start_with?("changed_") || key == "files"
        else
          unless entry.is_a?(Integer) || entry.is_a?(Float) || entry.is_a?(String) || entry.nil? || entry == true || entry == false
            raise ArgumentError, "evidence_summary values must be primitives"
          end
          if entry.is_a?(String) && entry.bytesize > 4096
            raise ArgumentError, "evidence_summary string values too large"
          end
        end
      end

      value.dup.freeze
    end

    def require_nonempty_string(value, name, max_length)
      unless value.is_a?(String) && !value.empty? && value.bytesize <= max_length
        raise ArgumentError, "#{name} must be a non-empty string of at most #{max_length} bytes"
      end

      value
    end
  end
end
