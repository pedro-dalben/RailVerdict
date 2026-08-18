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

      MAX_TOOL_RESPONSE_BYTES = 256 * 1024

      def self.tool_response(structured, error: false)
        text = text_content(structured)
        if text.bytesize > MAX_TOOL_RESPONSE_BYTES
          truncated = truncate_structured(structured)
          if truncated
            structured = truncated
            text = text_content(structured)
          else
            payload = { "code" => "response_too_large", "message" => "response exceeds #{MAX_TOOL_RESPONSE_BYTES} bytes; use list_findings/get_finding with pagination" }
            return ::MCP::Tool::Response.new([{ type: "text", text: JSON.generate(payload) }], error: true, structured_content: payload)
          end
        end
        ::MCP::Tool::Response.new([{ type: "text", text: text }], error: error, structured_content: structured)
      end

      def self.truncate_structured(structured)
        return nil unless structured.is_a?(Hash)

        if structured.key?("findings") && structured["findings"].is_a?(Array) && structured["findings"].length > 10
          copy = structured.dup
          copy["findings"] = structured["findings"].first(20)
          copy["truncated_due_to_size"] = true
          copy["total"] ||= structured["findings"].length
          return copy if JSON.generate(copy).bytesize <= MAX_TOOL_RESPONSE_BYTES
        end
        if structured.key?("gate_result") && structured["gate_result"].is_a?(Hash)
          gr = structured["gate_result"]
          if gr["findings"] && gr["findings"].is_a?(Array) && gr["findings"].length > 10
            copy = structured.dup
            copy["gate_result"] = gr.dup
            copy["gate_result"]["findings"] = gr["findings"].first(20)
            copy["gate_result"]["truncated_due_to_size"] = true
            return copy if JSON.generate(copy).bytesize <= MAX_TOOL_RESPONSE_BYTES
          end
        end
        nil
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
