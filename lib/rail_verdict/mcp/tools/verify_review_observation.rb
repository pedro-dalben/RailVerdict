# frozen_string_literal: true

require_relative "../serializers"

module RailVerdict
  module MCP
    module Tools
      # Validate an outside observation against freshly re-observed state.
      # Gate-neutral by construction: proves reference to a state, never
      # correctness of the conclusion, and alters nothing.
      class VerifyReviewObservation
        MAX_OBSERVATION_BYTES = 256 * 1024

        def initialize(server:)
          @server = server
        end

        def tool_name
          "verify_review_observation"
        end

        def tool_title
          "Verify review observation"
        end

        def tool_description
          "Validate a review observation document against the current repository state, configuration, and policy. Returns valid_bound, stale, untrusted, invalid, or unavailable. Validation never changes any gate, requirement, finding, receipt, or handoff."
        end

        def tool_input_schema
          {
            type: "object",
            properties: {
              observation: { type: "object" }
            },
            required: %w[observation],
            additionalProperties: false
          }
        end

        def tool_output_schema
          {
            type: "object",
            properties: {
              status: { type: "string", enum: %w[valid_bound stale untrusted invalid unavailable] },
              observation_id: { type: ["string", "null"] },
              code: { type: "string" },
              message: { type: "string" }
            },
            required: %w[status]
          }
        end

        def tool_annotations
          { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false, title: tool_title }
        end

        def call(observation: nil, **_rest)
          unless observation.is_a?(Hash)
            return Serializers.tool_response(
              { "status" => "invalid", "code" => "observation_malformed",
                "message" => "observation must be an object" }, error: false)
          end
          if JSON.generate(observation).bytesize > MAX_OBSERVATION_BYTES
            return Serializers.tool_response(
              { "status" => "invalid", "code" => "observation_too_large",
                "message" => "observation exceeds 256 KiB" }, error: false)
          end

          root = @server.repository_root
          outcome = begin
            @server.cache.fetch_outcome
          rescue StandardError
            nil
          end
          configuration = outcome&.configuration
          if configuration.nil?
            begin
              configuration = RailVerdict::Configuration.load(File.join(File.realpath(root), ".railverdict.yml"))
            rescue StandardError
              configuration = nil
            end
          end
          if configuration.nil?
            return Serializers.tool_response(
              { "status" => "unavailable", "code" => "observation_configuration_unavailable",
                "message" => "observation binding requires a readable configuration file" }, error: false)
          end

          effective_paths = begin
            RailVerdict::Check.effective_input_paths(root: File.realpath(root), config_path: File.join(File.realpath(root), ".railverdict.yml"))
          rescue StandardError
            nil
          end
          current_state = RailVerdict::RepositoryState.capture(repository_root: root, configuration_paths: effective_paths)
          components = current_state.projection&.fetch("components", nil)
          head = components.is_a?(Hash) ? components["head"] : nil
          current = {
            "head" => head,
            "configuration_digest" => configuration.digest,
            "policy_digest" => RailVerdict::EngineeringPolicy.policy_digest(
              RailVerdict::EngineeringPolicy.effective_policy(configuration))
          }
          verdict = RailVerdict::ReviewObservation.validate(observation: observation, current: current)
          Serializers.tool_response(Serializers.scrub(verdict), error: false)
        rescue StandardError => e
          Serializers.error_response("verify_review_observation failed: #{e.message}", code: "internal_error")
        end
      end
    end
  end
end
