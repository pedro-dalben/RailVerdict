# frozen_string_literal: true

require_relative "../serializers"

module RailVerdict
  module MCP
    module Tools
      class GetPRIntelligence
        def initialize(server:)
          @server = server
        end

        def tool_name
          "get_pr_intelligence"
        end

        def tool_title
          "Get PR intelligence"
        end

        def tool_description
          "Return the PR Intelligence + Change Intelligence document from the most recent changed-scope verify, WITHOUT rerunning analyzers. Same canonical verification as the receipt and CLI: gate, change surfaces, review signals/risk, verification scope (full vs targeted), missing evidence, and review focus. Stale or unavailable evidence is reported explicitly."
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
              pr_intelligence: { type: ["object", "null"] },
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
            document = entry&.pr_intelligence_document
            if document.is_a?(Hash)
              payload = { "status" => "fresh", "pr_intelligence" => Serializers.scrub(document) }
            else
              payload = {
                "status" => "state_unavailable",
                "code" => "pr_intelligence_unavailable",
                "message" => "last verification did not produce PR Intelligence (changed scope required)"
              }
            end
            Serializers.tool_response(payload, error: false)
          when "stale"
            Serializers.tool_response(
              { "status" => "verification_required", "code" => "stale_intelligence", "message" => "repository state changed since the last verify; run verify again" },
              error: false
            )
          when "state_unavailable"
            Serializers.tool_response(
              { "status" => "state_unavailable", "code" => "repository_state_unavailable", "message" => "current repository state could not be determined fail-closed" },
              error: false
            )
          else
            Serializers.tool_response(
              { "status" => "verification_required", "code" => "no_verification_yet", "message" => "run verify before requesting PR intelligence" },
              error: false
            )
          end
        rescue StandardError => e
          Serializers.error_response("get_pr_intelligence failed: #{e.message}", code: "internal_error")
        end
      end
    end
  end
end
