# frozen_string_literal: true

require "digest"

module RailVerdict
  # Workflow closure record (1.8, ADR 0021).
  #
  # Binds one review packet, the policy decision, and validated observations to
  # final readiness. Reports only: reclassifies no opinion as fact and rewrites
  # no gate.
  module WorkflowReceipt
    SCHEMA_VERSION = "1.0"
    MAX_OBSERVATIONS = 32

    module_function

    def build(packet:, policy_decision:, gate:, observations: [])
      unless packet.is_a?(Hash)
        raise RailVerdict::Error, "workflow receipt requires a review packet document"
      end
      packet_gate = packet.dig("deterministic", "verification", "gate")
      packet_decision = packet.dig("deterministic", "policy", "decision")
      unless gate.to_s == packet_gate.to_s
        raise RailVerdict::Error, "gate #{gate.inspect} does not match packet gate #{packet_gate.inspect}: refusing mix-and-match"
      end
      unless policy_decision.to_s == packet_decision.to_s
        raise RailVerdict::Error, "policy decision #{policy_decision.inspect} does not match packet decision #{packet_decision.inspect}: refusing mix-and-match"
      end
      validated = Array(observations).first(MAX_OBSERVATIONS).map do |entry|
        {
          "observation_id" => entry["observation_id"].to_s,
          "author" => entry["author"].to_s,
          "binding" => entry["binding"].to_s
        }
      end
      readiness, codes = readiness_for(gate: gate, policy_decision: policy_decision, validated: validated)
      receipt = {
        "schema_version" => SCHEMA_VERSION,
        "workflow_receipt_id" => "sha256:#{'0' * 64}",
        "packet_id" => packet["packet_id"].to_s,
        "policy_digest" => packet.dig("deterministic", "policy", "policy_digest").to_s,
        "gate" => gate.to_s,
        "policy_decision" => policy_decision.to_s,
        "readiness" => readiness,
        "reason_codes" => codes.sort,
        "observations" => validated.sort_by { |entry| entry["observation_id"] }
      }
      receipt["workflow_receipt_id"] = receipt_id(receipt)

      errors = SchemaValidator.validate_workflow_receipt(receipt)
      raise RailVerdict::Error, "workflow-receipt-v1 validation failed: #{errors.join('; ')}" unless errors.empty?

      receipt
    end

    def receipt_id(receipt)
      core = receipt.reject { |key, _| key == "workflow_receipt_id" }
      "sha256:#{Digest::SHA256.hexdigest(CanonicalJSON.generate(core))}"
    end

    def readiness_for(gate:, policy_decision:, validated:)
      if gate.to_s == "FAIL"
        ["blocked_by_gate", ["workflow_blocked_by_gate"]]
      elsif gate.to_s == "INCOMPLETE" || policy_decision.to_s == "INCOMPLETE"
        ["blocked_by_evidence", ["workflow_blocked_by_evidence"]]
      elsif policy_decision.to_s == "FAIL"
        ["blocked_by_evidence", %w[workflow_blocked_by_evidence workflow_policy_fail]]
      elsif policy_decision.to_s == "REVIEW_REQUIRED"
        ["review_pending", ["workflow_review_pending"]]
      else
        codes = ["workflow_ready"]
        codes << "workflow_observations_bound" unless validated.empty?
        ["ready", codes]
      end
    end
  end
end
