# frozen_string_literal: true

require_relative "../serializers"

module RailVerdict
  module MCP
    module Tools
      class GetVerificationReceipt
        def initialize(server:)
          @server = server
        end

        def tool_name
          "get_verification_receipt"
        end

        def tool_title
          "Get verification receipt"
        end

        def tool_description
          "Return the Verification Receipt from the most recent verify, WITHOUT rerunning analyzers. Fresh receipts bind the exact repository state that was verified. If the repository changed after verify, returns verification_required/stale instead of stale evidence."
        end

        def tool_input_schema
          {
            type: "object",
            properties: {},
            additionalProperties: false
          }
        end

        def tool_output_schema
          {
            type: "object",
            properties: {
              status: { type: "string", enum: %w[fresh stale verification_required state_unavailable] },
              receipt: { type: ["object", "null"] },
              code: { type: "string" },
              message: { type: "string" }
            },
            required: %w[status]
          }
        end

        def tool_annotations
          { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false, title: tool_title }
        end

        def call(**_rest)
          current_state = RailVerdict::RepositoryState.capture(repository_root: @server.repository_root)
          case @server.cache.verification_state(current_state)
          when "fresh"
            entry = @server.cache.fresh_entry(current_state)
            receipt = entry&.receipt_document
            if receipt.is_a?(Hash) && receipt["receipt_id"]
              payload = { "status" => "fresh", "receipt" => Serializers.scrub(receipt) }
            else
              payload = {
                "status" => "state_unavailable",
                "code" => receipt.is_a?(Hash) ? receipt["code"] : "repository_state_unavailable",
                "message" => "last verification could not be bound to a stable repository state; run verify again"
              }
            end
            Serializers.tool_response(payload, error: false)
          when "stale"
            Serializers.tool_response(
              { "status" => "verification_required", "code" => "stale_receipt", "message" => "repository state changed since the last verify; the previous receipt is stale and must not be used as current evidence" },
              error: false
            )
          when "state_unavailable"
            Serializers.tool_response(
              { "status" => "state_unavailable", "code" => "repository_state_unavailable", "message" => "current repository state could not be determined fail-closed" },
              error: false
            )
          else
            Serializers.tool_response(
              { "status" => "verification_required", "code" => "no_verification_yet", "message" => "run verify before requesting a receipt" },
              error: false
            )
          end
        rescue StandardError => e
          Serializers.error_response("get_verification_receipt failed: #{e.message}", code: "internal_error")
        end
      end
    end
  end
end
