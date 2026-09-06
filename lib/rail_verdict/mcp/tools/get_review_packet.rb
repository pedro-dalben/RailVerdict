# frozen_string_literal: true

require_relative "../serializers"

module RailVerdict
  module MCP
    module Tools
      # Bounded review context for the most recent verify, WITHOUT rerunning
      # analyzers. Same canonical ReviewPacket service as `railverdict review`:
      # deterministic and review lanes structurally separated, context only.
      class GetReviewPacket
        def initialize(server:)
          @server = server
        end

        def tool_name
          "get_review_packet"
        end

        def tool_title
          "Get review packet"
        end

        def tool_description
          "Return the Review Packet (verification, plan, policy, evidence gaps with recovery, review focus) from the most recent verify, WITHOUT rerunning analyzers. Deterministic evidence and review evidence travel in separate lanes. Stale or unavailable evidence is reported explicitly."
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
              review_packet: { type: ["object", "null"] },
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
            if outcome.nil? || !document.is_a?(Hash)
              payload = {
                "status" => "state_unavailable",
                "code" => "review_context_unavailable",
                "message" => "last verification did not retain the outcome needed for review context"
              }
            elsif outcome.configuration.nil?
              payload = {
                "status" => "state_unavailable",
                "code" => "review_configuration_unavailable",
                "message" => "review context requires a readable configuration file"
              }
            else
              packet = RailVerdict::ReviewPacket.build(outcome: outcome, pr_document: document)
              payload = { "status" => "fresh", "review_packet" => Serializers.scrub(packet) }
            end
            Serializers.tool_response(payload, error: false)
          when "stale"
            Serializers.tool_response(
              { "status" => "verification_required", "code" => "stale_review", "message" => "repository state changed since the last verify; run verify again" },
              error: false
            )
          when "state_unavailable"
            Serializers.tool_response(
              { "status" => "state_unavailable", "code" => "repository_state_unavailable", "message" => "current repository state could not be determined fail-closed" },
              error: false
            )
          else
            Serializers.tool_response(
              { "status" => "verification_required", "code" => "no_verification_yet", "message" => "run verify before requesting the review packet" },
              error: false
            )
          end
        rescue StandardError => e
          Serializers.error_response("get_review_packet failed: #{e.message}", code: "internal_error")
        end
      end
    end
  end
end
