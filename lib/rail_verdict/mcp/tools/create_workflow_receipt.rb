# frozen_string_literal: true

require_relative "../serializers"

module RailVerdict
  module MCP
    module Tools
      # Assemble the workflow closure record from the cached verify outcome
      # plus caller-supplied observations. Freshness is automatic: a stale
      # cache yields verification_required, never a receipt.
      class CreateWorkflowReceipt
        MAX_OBSERVATIONS = 32

        def initialize(server:)
          @server = server
        end

        def tool_name
          "create_workflow_receipt"
        end

        def tool_title
          "Create workflow receipt"
        end

        def tool_description
          "Build the workflow receipt (packet binding, policy decision, validated observations, final readiness) from the most recent verify plus inline observations, WITHOUT rerunning analyzers. Reports only; reclassifies nothing and rewrites no gate."
        end

        def tool_input_schema
          {
            type: "object",
            properties: {
              observations: {
                type: "array",
                maxItems: MAX_OBSERVATIONS,
                items: { type: "object" }
              }
            },
            additionalProperties: false
          }
        end

        def tool_output_schema
          {
            type: "object",
            properties: {
              status: { type: "string", enum: %w[fresh stale verification_required state_unavailable] },
              workflow_receipt: { type: ["object", "null"] },
              code: { type: "string" },
              message: { type: "string" }
            },
            required: %w[status]
          }
        end

        def tool_annotations
          { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false, title: tool_title }
        end

        def call(observations: nil, **_rest)
          inline = Array(observations).first(MAX_OBSERVATIONS)
          root = @server.repository_root
          effective_paths = begin
            RailVerdict::Check.effective_input_paths(root: File.realpath(root), config_path: File.join(File.realpath(root), ".railverdict.yml"))
          rescue StandardError
            nil
          end
          current_state = RailVerdict::RepositoryState.capture(repository_root: root, configuration_paths: effective_paths)
          current_env = begin
            outcome = @server.cache.fetch_outcome
            config = outcome&.configuration
            RailVerdict::VerificationEnvironment.capture(repository_root: root, configuration: config)
          rescue StandardError
            nil
          end
          case @server.cache.verification_state(current_state, current_env)
          when "fresh"
            entry = @server.cache.fresh_entry(current_state, current_env)
            outcome = begin
              @server.cache.fetch_outcome
            rescue StandardError
              nil
            end
            document = entry&.pr_intelligence_document
            if outcome.nil? || !document.is_a?(Hash) || outcome.configuration.nil?
              payload = {
                "status" => "state_unavailable",
                "code" => "workflow_context_unavailable",
                "message" => "last verification did not retain the outcome needed for workflow closure"
              }
            else
              packet = RailVerdict::ReviewPacket.build(outcome: outcome, pr_document: document)
              policy = RailVerdict::EngineeringPolicy.evaluate(outcome: outcome, pr_document: document)
              current = {
                "head" => packet["provenance"]["head"],
                "configuration_digest" => packet["provenance"]["configuration_digest"],
                "policy_digest" => policy["policy_digest"]
              }
              validated = inline.map do |observation|
                verdict = RailVerdict::ReviewObservation.validate(observation: observation, current: current)
                author = observation.is_a?(Hash) ? observation["author"].to_s : "unknown"
                { "observation_id" => verdict["observation_id"].to_s,
                  "author" => author, "binding" => verdict["status"] }
              end
              receipt = RailVerdict::WorkflowReceipt.build(packet: packet,
                policy_decision: policy["decision"], gate: outcome.result.gate, observations: validated)
              payload = { "status" => "fresh", "workflow_receipt" => Serializers.scrub(receipt) }
            end
            Serializers.tool_response(payload, error: false)
          when "stale"
            Serializers.tool_response(
              { "status" => "verification_required", "code" => "stale_workflow", "message" => "repository state changed since the last verify; run verify again" },
              error: false
            )
          when "state_unavailable"
            Serializers.tool_response(
              { "status" => "state_unavailable", "code" => "repository_state_unavailable", "message" => "current repository state could not be determined fail-closed" },
              error: false
            )
          else
            Serializers.tool_response(
              { "status" => "verification_required", "code" => "no_verification_yet", "message" => "run verify before closing the workflow" },
              error: false
            )
          end
        rescue StandardError => e
          Serializers.error_response("create_workflow_receipt failed: #{e.message}", code: "internal_error")
        end
      end
    end
  end
end
