# frozen_string_literal: true

require "json"

module RailVerdict
  module MCP
    module Serializers
      def self.scrub(value)
        case value
        when String
          value.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD").gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "?")
        when Hash
          value.transform_keys { |k| scrub(k) }.transform_values { |v| scrub(v) }
        when Array
          value.map { |v| scrub(v) }
        else
          value
        end
      end

      def self.gate_result_to_structured(outcome)
        result = outcome.result
        h = result.to_schema_h
        h["findings"] = h["findings"] || []
        h
      end

      def self.text_content(structured)
        scrub(JSON.generate(structured))
      end

      def self.tool_response(structured, error: false)
        text = text_content(structured)
        ::MCP::Tool::Response.new([{ type: "text", text: text }], error: error, structured_content: structured)
      end

      def self.error_response(message, code: "invalid_arguments")
        scrubbed = scrub(message)
        payload = { "code" => code, "message" => scrubbed }
        ::MCP::Tool::Response.new([{ type: "text", text: JSON.generate(payload) }], error: true, structured_content: payload)
      end

      def self.bounded_findings(findings, limit, offset)
        total = findings.length
        slice = findings.slice(offset, limit) || []
        {
          "findings" => slice.map(&:to_schema_h),
          "total" => total,
          "limit" => limit,
          "offset" => offset,
          "truncated" => (offset + limit) < total
        }
      end
    end
  end
end
