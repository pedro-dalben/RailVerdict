# frozen_string_literal: true

module RailVerdict
  module MCP
    module Tools
      class InspectHandoff
        def initialize(server:)
          @server = server
        end

        def tool_name
          "inspect_handoff"
        end

        def tool_title
          "Inspect verification handoff"
        end

        def tool_description
          "Parse and validate a Verification Handoff. Bounded, deterministic, tamper-detected via handoff_id. Does not execute analyzers."
        end

        def tool_input_schema
          {
            type: "object",
            properties: {
              handoff: { type: "object", description: "Handoff document to inspect" },
              handoff_json: { type: "string", description: "Handoff JSON string (alternative to handoff object)" }
            },
            additionalProperties: false
          }
        end

        def tool_output_schema
          {
            type: "object",
            properties: {
              valid: { type: "boolean" },
              handoff: { type: ["object", "null"] },
              error: { type: "string" },
              handoff_id: { type: "string" }
            },
            required: %w[valid]
          }
        end

        def tool_annotations
          { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false, title: tool_title }
        end

        def call(handoff: nil, handoff_json: nil, **_rest)
          text = if handoff_json && !handoff_json.to_s.strip.empty?
                   handoff_json.to_s
                 elsif handoff
                   JSON.generate(handoff)
                 else
                   return Serializers.error_response("handoff or handoff_json is required", code: "invalid_arguments")
                 end
          return Serializers.error_response("handoff too large", code: "handoff_too_large") if text.bytesize > Handoff::MAX_DOCUMENT_BYTES
          doc, err = Handoff.parse(text)
          if doc
            Serializers.tool_response({ "valid" => true, "handoff" => Serializers.scrub(doc), "handoff_id" => doc["handoff_id"] }, error: false)
          else
            Serializers.tool_response({ "valid" => false, "error" => err.to_s, "handoff" => nil }, error: false)
          end
        rescue StandardError => e
          Serializers.error_response("inspect_handoff failed: #{e.message}", code: "internal_error")
        end
      end
    end
  end
end
