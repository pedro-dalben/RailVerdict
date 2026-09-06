# frozen_string_literal: true

require "digest"

module RailVerdict
  # Bounded outside observations plus fail-closed validation (1.8, ADR 0021).
  #
  # Observations are always non-authoritative: validation proves reference to a
  # state (fresh binding), never correctness of the conclusion, and never
  # alters any gate, requirement, finding, receipt, or handoff.
  module ReviewObservation
    SCHEMA_VERSION = "1.0"
    AUTHORS = %w[human agent ai].freeze
    CONFIDENCES = %w[low medium high].freeze
    MAX_OBSERVATIONS = 32
    MAX_PATHS = 16

    module_function

    def build(author:, confidence:, state_binding:, observations:, provider: nil, model: nil)
      body = {
        "schema_version" => SCHEMA_VERSION,
        "author" => author.to_s,
        "confidence" => confidence.to_s,
        "authoritative" => false,
        "state_binding" => {
          "head" => state_binding["head"].to_s,
          "configuration_digest" => state_binding["configuration_digest"].to_s,
          "policy_digest" => state_binding["policy_digest"].to_s
        },
        "observations" => Array(observations).map do |item|
          entry = { "summary" => item["summary"].to_s[0, 1024] }
          entry["paths"] = Array(item["paths"]).map(&:to_s).first(MAX_PATHS) if item["paths"]
          entry["severity"] = item["severity"].to_s if item["severity"]
          entry
        end
      }
      body["provider"] = provider.to_s[0, 128] unless provider.nil?
      body["model"] = model.to_s[0, 128] unless model.nil?
      body["observation_id"] = observation_id(body)

      errors = SchemaValidator.validate_review_observation(body)
      raise RailVerdict::Error, "review-observation-v1 validation failed: #{errors.join('; ')}" unless errors.empty?

      body
    end

    def observation_id(body)
      core = body.reject { |key, _| key == "observation_id" }
      "sha256:#{Digest::SHA256.hexdigest(CanonicalJSON.generate(core))}"
    end

    # current: {head, configuration_digest, policy_digest} freshly observed by
    # the caller. Returns {status, code, observation_id}. Order is deliberate:
    # shape, then author/provider trust, then schema detail, then binding.
    def validate(observation:, current:)
      unless observation.is_a?(Hash)
        return { "status" => "invalid", "code" => "observation_malformed", "observation_id" => nil }
      end

      author = observation["author"]
      unless AUTHORS.include?(author)
        return { "status" => "untrusted", "code" => "observation_author_unknown", "observation_id" => nil }
      end
      if (author == "agent" || author == "ai") && observation["provider"].to_s.strip.empty?
        return { "status" => "untrusted", "code" => "observation_provider_missing", "observation_id" => nil }
      end

      errors = SchemaValidator.validate_review_observation(observation)
      unless errors.empty?
        return { "status" => "invalid", "code" => "observation_schema_invalid", "observation_id" => nil }
      end

      expected = observation_id(observation)
      unless observation["observation_id"] == expected
        return { "status" => "invalid", "code" => "observation_integrity_failed", "observation_id" => nil }
      end

      unless current.is_a?(Hash) && current["head"].is_a?(String)
        return { "status" => "unavailable", "code" => "observation_state_unobservable", "observation_id" => expected }
      end

      binding = observation["state_binding"]
      if binding["head"] != current["head"]
        return { "status" => "stale", "code" => "observation_state_moved", "observation_id" => expected }
      end
      if binding["configuration_digest"] != current["configuration_digest"] ||
          binding["policy_digest"] != current["policy_digest"]
        return { "status" => "stale", "code" => "observation_policy_moved", "observation_id" => expected }
      end

      { "status" => "valid_bound", "code" => "observation_bound", "observation_id" => expected }
    end
  end
end
