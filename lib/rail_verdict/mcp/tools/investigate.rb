# frozen_string_literal: true

module RailVerdict
  module MCP
    module Tools
      class Investigate
        def initialize(server:)
          @server = server
        end

        def tool_name
          "investigate"
        end

        def tool_title
          "Investigate findings (advisory AI)"
        end

        def tool_description
          "Advisory AI — requires ai.enabled and ai.remote.enabled. Investigate up to 3 findings. Use preview to inspect manifests without network. Budgets enforced before provider. AI never changes gate."
        end

        def tool_input_schema
          {
            type: "object",
            properties: {
              limit: { type: "integer", description: "Max findings to investigate (1..3, default 3)" },
              preview: { type: "boolean", description: "If true, return manifests only (no provider calls)" }
            },
            additionalProperties: false
          }
        end

        def tool_output_schema
          {
            type: "object",
            properties: {
              preview: { type: "boolean" },
              manifests: { type: "array" },
              results: { type: "array" }
            }
          }
        end

        def tool_annotations
          { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false, title: tool_title }
        end

        def call(limit: nil, preview: nil, **_rest)
          begin
            limit_v = limit.nil? ? 3 : limit
            unless limit_v.is_a?(Integer) && limit_v.between?(1, 3)
              raise ArgumentError, "limit must be an integer between 1 and 3"
            end
            preview_v = preview == true

            outcome = @server.cache.fetch_outcome
            unless outcome
              outcome = Check.execute(repository_root: @server.repository_root, config_path: File.join(@server.repository_root, ".railverdict.yml"))
              @server.cache.store_outcome(outcome)
            end

            if preview_v
              findings = Intelligence::Budget.select_findings(outcome.findings || [], limit: limit_v)
              manifests = findings.map do |f|
                Intelligence::ContextBuilder.build(outcome: outcome, finding_ref: f.id).to_json_hash
              rescue StandardError => e
                { "finding_id" => f.id, "error" => e.message }
              end
              structured = { "preview" => true, "manifests" => manifests }
              structured = Serializers.scrub(structured)
              return Serializers.tool_response(structured, error: false)
            end

            unless ai_enabled?(outcome.configuration)
              return Serializers.error_response("AI is off — set ai.enabled=true and ai.remote.enabled=true in .railverdict.yml", code: "ai_disabled")
            end

            results = Intelligence::Orchestrator.investigate(outcome: outcome, configuration: outcome.configuration, limit: limit_v)
            payload = results.map do |r|
              if r[:failure]
                { "failure" => r[:failure].to_h, "analysis" => nil }
              else
                { "failure" => nil, "analysis" => r[:analysis]&.to_h }
              end
            end
            structured = { "results" => payload }
            structured = Serializers.scrub(structured)
            Serializers.tool_response(structured, error: false)
          rescue ArgumentError => e
            Serializers.error_response(e.message, code: "invalid_arguments")
          rescue StandardError => e
            Serializers.error_response("investigate failed: #{e.message}", code: "internal_error")
          end
        end

        private

        def ai_enabled?(config)
          return false unless config

          config.ai_enabled? && config.ai_remote_enabled?
        end
      end
    end
  end
end
