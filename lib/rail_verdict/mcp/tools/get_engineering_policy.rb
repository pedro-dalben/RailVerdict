# frozen_string_literal: true

require_relative "../serializers"

module RailVerdict
  module MCP
    module Tools
      # Engineering policy evaluation over the most recent verify, WITHOUT
      # rerunning analyzers. Same canonical EngineeringPolicy service as
      # `railverdict policy`: GateResult stays the authority, this envelope
      # reports readiness (PASS/FAIL/INCOMPLETE/REVIEW_REQUIRED).
      class GetEngineeringPolicy
        def initialize(server:)
          @server = server
        end

        def tool_name
          "get_engineering_policy"
        end

        def tool_title
          "Get engineering policy"
        end

        def tool_description
          "Return the Engineering Policy evaluation (requirements, decision, readiness) from the most recent verify, WITHOUT rerunning analyzers. Same canonical policy service as the CLI: deterministic requirements derived from change intelligence, FAIL on violation, INCOMPLETE on missing evidence, REVIEW_REQUIRED on pending human review (never approval). Stale or unavailable evidence is reported explicitly."
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
              engineering_policy: { type: ["object", "null"] },
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
                "code" => "policy_context_unavailable",
                "message" => "last verification did not retain the outcome needed for policy evaluation"
              }
            elsif outcome.configuration.nil?
              payload = {
                "status" => "state_unavailable",
                "code" => "policy_configuration_unavailable",
                "message" => "policy evaluation requires a readable configuration file"
              }
            else
              envelope = RailVerdict::EngineeringPolicy.evaluate(outcome: outcome, pr_document: document)
              payload = { "status" => "fresh", "engineering_policy" => Serializers.scrub(envelope) }
            end
            Serializers.tool_response(payload, error: false)
          when "stale"
            Serializers.tool_response(
              { "status" => "verification_required", "code" => "stale_policy", "message" => "repository state changed since the last verify; run verify again" },
              error: false
            )
          when "state_unavailable"
            Serializers.tool_response(
              { "status" => "state_unavailable", "code" => "repository_state_unavailable", "message" => "current repository state could not be determined fail-closed" },
              error: false
            )
          else
            Serializers.tool_response(
              { "status" => "verification_required", "code" => "no_verification_yet", "message" => "run verify before requesting engineering policy" },
              error: false
            )
          end
        rescue StandardError => e
          Serializers.error_response("get_engineering_policy failed: #{e.message}", code: "internal_error")
        end
      end
    end
  end
end
