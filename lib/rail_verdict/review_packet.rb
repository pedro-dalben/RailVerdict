# frozen_string_literal: true

require "digest"

module RailVerdict
  # Canonical review-context builder (1.8, ADR 0021).
  #
  # Composes ONE Check outcome into a bounded ReviewPacket: deterministic lane
  # (verification, evidence, plan, policy, gaps, recovery) structurally split
  # from the review lane (risk, focus, surfaces). Context only, never a gate.
  module ReviewPacket
    SCHEMA_VERSION = "1.0"
    MAX_RECOVERY = 64

    module_function

    def build(outcome:, pr_document: nil, policy_envelope: nil)
      result = outcome.result
      configuration = outcome.configuration
      raise RailVerdict::Error, "review packet requires a readable configuration file" if configuration.nil?

      document = pr_document || PRIntelligence.document(outcome)
      policy = policy_envelope || EngineeringPolicy.evaluate(outcome: outcome, pr_document: document)

      packet = {
        "schema_version" => SCHEMA_VERSION,
        "packet_id" => "sha256:#{'0' * 64}",
        "provenance" => provenance(document, configuration),
        "deterministic" => {
          "verification" => verification(result),
          "analyzer_evidence" => analyzer_evidence(result),
          "plan" => plan(result, document, policy, configuration),
          "policy" => { "decision" => policy["decision"], "policy_digest" => policy["policy_digest"] },
          "evidence_gaps" => evidence_gaps(document),
          "recovery" => recovery(policy, document)
        },
        "review" => review_lane(document)
      }
      packet["packet_id"] = packet_id(packet)
      errors = SchemaValidator.validate_review_packet(packet)
      raise RailVerdict::Error, "review-packet-v1 validation failed: #{errors.join('; ')}" unless errors.empty?

      packet
    end

    def packet_id(packet)
      core = packet.reject { |key, _| key == "packet_id" }
      "sha256:#{Digest::SHA256.hexdigest(CanonicalJSON.generate(core))}"
    end

    def provenance(document, configuration)
      source = document["provenance"].is_a?(Hash) ? document["provenance"] : {}
      {
        "head" => source["head"],
        "base" => source["base"],
        "merge_base" => source["merge_base"],
        "configuration_digest" => configuration.digest
      }
    end

    def verification(result)
      reasons = Array(result.decision_reasons).map { |reason| reason["code"].to_s }.sort.uniq
      findings = Array(result.findings)
      {
        "gate" => result.gate,
        "completion_status" => result.completion_status,
        "policy_status" => result.policy_status,
        "decision_reason_codes" => reasons,
        "findings_total" => findings.length,
        "findings_blocking" => findings.count { |finding| finding["blocking"] }
      }
    end

    def analyzer_evidence(result)
      result.analyzer_results.sort_by(&:analyzer).map do |analyzer|
        {
          "analyzer" => analyzer.analyzer,
          "execution_status" => analyzer.execution_status.to_s,
          "evidence_status" => analyzer.evidence_status.to_s
        }
      end
    end

    def plan(result, document, policy, configuration)
      evidence = analyzer_evidence(result)
      executed = evidence.select { |entry| entry["evidence_status"] == "complete" }
        .map { |entry| entry["analyzer"] }.sort
      required_names = configuration.analyzers.select { |_, selection| selection["enabled"] && selection["required"] }.keys.map(&:to_s)
      missing = required_names.select do |name|
        entry = evidence.find { |item| item["analyzer"] == name }
        entry.nil? || entry["evidence_status"] != "complete"
      end.sort
      scope = document["verification_scope"].is_a?(Hash) ? document["verification_scope"] : {}
      frameworks = scope["frameworks"].is_a?(Hash) ? scope["frameworks"] : {}
      test_scope = frameworks.to_h do |name, entry|
        [name.to_s, { "executed" => entry["executed"] == true, "scope" => entry["scope"].to_s }]
      end
      requirements = Array(policy["requirements"]).map do |entry|
        { "id" => entry["id"], "status" => entry["status"] }
      end.sort_by { |entry| entry["id"] }
      {
        "analyzers_executed" => executed,
        "analyzers_required_missing" => missing,
        "test_scope" => test_scope,
        "requirements" => requirements,
        "reasons" => Array(policy["reason_codes"]).sort
      }
    end

    def evidence_gaps(document)
      Array(document["missing_evidence"]).map do |gap|
        {
          "code" => gap["code"].to_s,
          "detail" => gap["detail"].to_s[0, 512],
          "reason" => gap["reason"].to_s[0, 256]
        }
      end
    end

    def recovery(policy, document)
      from_policy = Array(policy["requirements"]).filter_map do |entry|
        action = entry["recovery_action"]
        next if action.nil? || action.to_s.strip.empty?

        { "source" => "policy:#{entry['id']}", "action" => action.to_s[0, 512] }
      end.sort_by { |entry| entry["source"] }
      covered = from_policy.map { |entry| entry["source"] }
      gaps = Array(document["missing_evidence"]).filter_map do |gap|
        code = gap["code"].to_s
        next if code.empty?

        { "source" => "evidence:#{code}", "action" => "resolve evidence gap #{code}: #{gap['reason']}"[0, 512] }
      end.sort_by { |entry| entry["source"] }
      (from_policy + gaps.reject { |entry| covered.any? { |source| entry["action"].include?(source) } })
        .first(MAX_RECOVERY)
    end

    def review_lane(document)
      risk = document["review_risk"].is_a?(Hash) ? document["review_risk"] : {}
      surfaces = document["surfaces"].is_a?(Hash) ? document["surfaces"] : {}
      areas = document["project_sensitive_areas"].is_a?(Array) ? document["project_sensitive_areas"] : []
      focus = Array(document["review_focus"]).map do |item|
        {
          "rank" => item["rank"].to_i,
          "surface" => item["surface"].to_s,
          "title" => item["title"].to_s[0, 256],
          "reason" => item["reason"].to_s[0, 256]
        }
      end
      {
        "risk_level" => risk["level"].to_s,
        "risk_reasons" => Array(risk["reasons"]).map(&:to_s).sort,
        "surfaces_changed" => surfaces.select { |_, entry| entry["changed"] == true }.keys.sort,
        "sensitive_areas" => areas.select { |area| area["changed"] == true }.map { |area| area["name"].to_s }.sort,
        "focus" => focus
      }
    end
  end
end
