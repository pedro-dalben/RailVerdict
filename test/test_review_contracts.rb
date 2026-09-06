# frozen_string_literal: true

require_relative "test_helper"

# Contract tests for review workflow schemas (1.8, ADR 0021): version dispatch,
# closed lanes, bounds, round-trips, and proof that repair-packet-v1 stayed
# backward compatible.
class TestReviewContracts < Minitest::Test
  def packet_doc
    {
      "schema_version" => "1.0", "packet_id" => "sha256:#{'a' * 64}",
      "provenance" => { "head" => "b" * 40, "base" => "main", "merge_base" => nil, "configuration_digest" => "c" * 64 },
      "deterministic" => {
        "verification" => { "gate" => "PASS", "completion_status" => "complete", "policy_status" => "pass",
                             "decision_reason_codes" => ["x"], "findings_total" => 0, "findings_blocking" => 0 },
        "analyzer_evidence" => [{ "analyzer" => "rubocop", "execution_status" => "succeeded", "evidence_status" => "complete" }],
        "plan" => { "analyzers_executed" => ["rubocop"], "test_scope" => {},
                    "requirements" => [{ "id" => "r1", "status" => "satisfied" }], "reasons" => ["y"] },
        "policy" => { "decision" => "PASS", "policy_digest" => "d" * 64 },
        "evidence_gaps" => [{ "code" => "c", "reason" => "r" }],
        "recovery" => [{ "source" => "policy:r1", "action" => "do x" }]
      },
      "review" => { "risk_level" => "LOW", "risk_reasons" => [], "surfaces_changed" => [],
                    "focus" => [{ "rank" => 1, "surface" => "models", "title" => "t", "reason" => "r" }] }
    }
  end

  def observation_doc
    {
      "schema_version" => "1.0", "observation_id" => "sha256:#{'e' * 64}",
      "author" => "agent", "provider" => "acme", "confidence" => "medium", "authoritative" => false,
      "state_binding" => { "head" => "b" * 40, "configuration_digest" => "c" * 64, "policy_digest" => "d" * 64 },
      "observations" => [{ "summary" => "noted" }]
    }
  end

  def test_packet_accepts_valid_rejects_malformed
    assert_empty RailVerdict::SchemaValidator.validate_review_packet(packet_doc)

    bad_gate = packet_doc.merge("deterministic" =>
      packet_doc["deterministic"].merge("verification" =>
        packet_doc["deterministic"]["verification"].merge("gate" => "MAYBE")))
    refute_empty RailVerdict::SchemaValidator.validate_review_packet(bad_gate)

    extra = packet_doc.merge("verdict" => "PASS")
    refute_empty RailVerdict::SchemaValidator.validate_review_packet(extra)

    lane_break = packet_doc.merge("deterministic" =>
      packet_doc["deterministic"].merge("review_risk" => "HIGH"))
    refute_empty RailVerdict::SchemaValidator.validate_review_packet(lane_break)

    oversized = packet_doc.merge("deterministic" =>
      packet_doc["deterministic"].merge("recovery" => Array.new(65) { { "source" => "s", "action" => "a" } }))
    refute_empty RailVerdict::SchemaValidator.validate_review_packet(oversized)

    missing = packet_doc.reject { |key, _| key == "packet_id" }
    refute_empty RailVerdict::SchemaValidator.validate_review_packet(missing)
  end

  def test_observation_accepts_valid_rejects_malformed
    assert_empty RailVerdict::SchemaValidator.validate_review_observation(observation_doc)

    human_provider = observation_doc.merge("author" => "human")
    refute_empty RailVerdict::SchemaValidator.validate_review_observation(human_provider)

    no_provider = observation_doc.reject { |key, _| key == "provider" }
    refute_empty RailVerdict::SchemaValidator.validate_review_observation(no_provider)

    authoritative = observation_doc.merge("authoritative" => true)
    refute_empty RailVerdict::SchemaValidator.validate_review_observation(authoritative)

    gated = observation_doc.merge("gate" => "PASS")
    refute_empty RailVerdict::SchemaValidator.validate_review_observation(gated)

    oversized = observation_doc.merge("observations" => Array.new(33) { { "summary" => "x" } })
    refute_empty RailVerdict::SchemaValidator.validate_review_observation(oversized)
  end

  def test_workflow_receipt_schema
    receipt = {
      "schema_version" => "1.0", "workflow_receipt_id" => "sha256:#{'f' * 64}",
      "packet_id" => "sha256:#{'a' * 64}", "gate" => "PASS", "policy_decision" => "PASS",
      "readiness" => "ready", "observations" => []
    }
    assert_empty RailVerdict::SchemaValidator.validate_workflow_receipt(receipt)

    bad_readiness = receipt.merge("readiness" => "almost")
    refute_empty RailVerdict::SchemaValidator.validate_workflow_receipt(bad_readiness)

    body = receipt.merge("observations" =>
      [{ "observation_id" => "sha256:#{'0' * 64}", "author" => "human", "binding" => "approved" }])
    refute_empty RailVerdict::SchemaValidator.validate_workflow_receipt(body)
  end

  def test_canonical_round_trip
    first = RailVerdict::CanonicalJSON.generate(packet_doc)
    second = RailVerdict::CanonicalJSON.generate(JSON.parse(first))
    assert_equal first, second
    assert(first.index('"completion_status"') < first.index('"decision"') ||
      first.index('"deterministic"') < first.index('"review"'))
    assert_empty RailVerdict::SchemaValidator.validate_review_packet(JSON.parse(first))
  end

  def test_old_repair_packets_still_validate
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, ".railverdict.yml"), <<~YAML)
        version: 1.4
        mode: strict
        analyzers:
          rubocop: { enabled: true, required: true }
      YAML
      fingerprint = RailVerdict::Fingerprint.hexdigest(analyzer: "rubocop", rule_id: "X",
        path: "a.rb", message: "m")
      finding = RailVerdict::Finding.new(fingerprint: fingerprint, origin: "deterministic",
        analyzer: "rubocop", rule_id: "X", category: "lint", severity: "high", confidence: "high",
        state: "introduced", evidence_ref: "r", location: { "path" => "a.rb", "start_line" => 1 },
        message: "m")
      analyzer_result = RailVerdict::AnalyzerResult.new(analyzer: "rubocop",
        invocation: { "executable" => "rubocop", "argv" => [] }, execution_status: "succeeded",
        finding_ids: [finding.id])
      result = RailVerdict::GateResult.new(completion_status: "complete", gate: "FAIL",
        policy_status: "fail",
        findings: [{ "id" => finding.id, "fingerprint" => finding.fingerprint, "severity" => "high",
                     "state" => "introduced", "blocking" => true }],
        analyzer_results: [analyzer_result], operational_failures: [],
        decision_reasons: [{ "code" => "x", "message" => "y" }])
      config = RailVerdict::Configuration.load(File.join(tmp, ".railverdict.yml"))
      context = RailVerdict::RunContext.build(repository_root: tmp, configuration: config,
        analyzer_versions: { "rubocop" => "1.0.0" }, revision_resolver: ->(_) { "abc1234" })
      outcome = RailVerdict::Check::Outcome.new(result: result, context: context,
        configuration: config, findings: [finding])
      packet = RailVerdict::Repair::ContextAssembler.build(outcome: outcome,
        finding_ref: finding.id, repository_root: tmp).to_h
      assert_empty RailVerdict::SchemaValidator.validate_repair_packet(packet)

      legacy = packet.dup
      legacy["verification_plan"] = {
        "required" => packet["verification_plan"]["required"],
        "suggested" => packet["verification_plan"]["suggested"]
      }
      assert_empty RailVerdict::SchemaValidator.validate_repair_packet(legacy)
    end
  end
end
