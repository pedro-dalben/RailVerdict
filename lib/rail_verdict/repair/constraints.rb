# frozen_string_literal: true

module RailVerdict
  module Repair
    module Constraints
      DEFAULT = {
        "forbid_baseline_update" => true,
        "forbid_waiver_creation" => true,
        "forbid_policy_relaxation" => true,
        "require_verification" => true
      }.freeze

      INSTRUCTIONS = [
        "Do not modify baseline files (.railverdict-baseline.json).",
        "Do not create waiver files (.railverdict-waivers.json).",
        "Do not weaken verification policy (mode strict/no_new_debt/advisory).",
        "Do not disable analyzers or make required analyzers optional.",
        "Preserve unrelated behavior; fix root cause, do not suppress the rule.",
        "Run required verification after modification."
      ].freeze

      def self.default
        DEFAULT.dup
      end

      def self.instructions
        INSTRUCTIONS.dup
      end
    end
  end
end
