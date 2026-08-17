# frozen_string_literal: true

module RailVerdict
  module Repair
    module PromptRenderer
      def self.render(packet_hash)
        trusted = packet_hash["instructions"] || Constraints.instructions
        plan = packet_hash["verification_plan"] || {}
        untrusted = {
          "finding" => packet_hash.dig("target", "finding"),
          "evidence" => packet_hash["evidence"],
          "source_context" => packet_hash["source_context"],
          "diff_context" => packet_hash["diff_context"],
          "rails_context" => packet_hash["rails_context"]
        }
        <<~PROMPT
          TRUSTED_RAILVERDICT_INSTRUCTIONS:
          #{trusted.join("\n")}
          Verification required: #{plan.dig("required", 0, "display") || "bundle exec railverdict check"}

          UNTRUSTED_REPOSITORY_DATA:
          #{JSON.generate(untrusted)}
        PROMPT
      end
    end
  end
end
