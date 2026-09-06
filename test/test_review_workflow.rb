# frozen_string_literal: true

require_relative "test_helper"

class TestReviewWorkflow < Minitest::Test
  FakeAnalyzer = Struct.new(:analyzer, :execution_status, :evidence_status)
  FakeResult = Struct.new(:gate, :completion_status, :policy_status, :decision_reasons, :findings, :analyzer_results)
  FakeOutcome = Struct.new(:result, :configuration)

  def configuration
    data = { "version" => 1.7, "mode" => "advisory",
             "analyzers" => { "rubocop" => { "enabled" => true, "required" => true } } }
    RailVerdict::Configuration.new(data, "/tmp/fake/.railverdict.yml", JSON.generate(data))
  end

  def pr_document
    {
      "provenance" => { "head" => "a" * 40, "base" => "main", "merge_base" => "b" * 40 },
      "surfaces" => { "migration" => { "changed" => true }, "models" => { "changed" => false } },
      "project_sensitive_areas" => [{ "name" => "billing", "changed" => false }],
      "review_risk" => { "level" => "HIGH", "reasons" => ["migration_added"], "configured" => false },
      "verification_scope" => { "available" => true,
        "frameworks" => { "rspec" => { "available" => true, "executed" => true, "scope" => "full" } } },
      "missing_evidence" => [{ "code" => "coverage_evidence_unavailable", "detail" => "no coverage",
                                "reason" => "simplecov did not produce evidence" }],
      "review_focus" => [{ "rank" => 1, "surface" => "migration", "title" => "Migration", "reason" => "schema change" }],
      "analyzer_evidence" => [{ "analyzer" => "rubocop", "execution_status" => "succeeded", "evidence_status" => "complete" }]
    }
  end

  def policy_envelope
    {
      "decision" => "REVIEW_REQUIRED",
      "policy_digest" => "c" * 64,
      "requirements" => [{
        "id" => "req-human-review-high", "kind" => "human_review", "trigger" => "t",
        "status" => "review_required", "required_evidence" => ["r"], "observed_evidence" => ["o"],
        "reason_codes" => ["human_review_required"], "provenance" => "p", "classification" => "review"
      }],
      "reason_codes" => %w[engineering_policy_review_required human_review_required]
    }
  end

  def outcome(gate: "PASS", completion: "complete")
    result = FakeResult.new(gate, completion, "pass",
      [{ "code" => "no_findings_detected" }], [], [FakeAnalyzer.new("rubocop", "succeeded", "complete")])
    FakeOutcome.new(result, configuration)
  end

  def packet
    RailVerdict::ReviewPacket.build(outcome: outcome, pr_document: pr_document, policy_envelope: policy_envelope)
  end

  def test_packet_validates_and_separates_lanes
    envelope = packet
    assert_empty RailVerdict::SchemaValidator.validate_review_packet(envelope)
    deterministic_keys = envelope["deterministic"].keys
    review_keys = envelope["review"].keys
    assert_empty deterministic_keys & review_keys
    assert_equal "PASS", envelope["deterministic"]["verification"]["gate"]
    assert_equal "REVIEW_REQUIRED", envelope["deterministic"]["policy"]["decision"]
    assert_equal "HIGH", envelope["review"]["risk_level"]
    assert_equal ["migration"], envelope["review"]["surfaces_changed"]
  end

  def test_packet_id_is_stable_and_bound
    first = packet
    second = packet
    assert_equal first["packet_id"], second["packet_id"]
    assert_match(/\Asha256:[0-9a-f]{64}\z/, first["packet_id"])
  end

  def test_packet_recovery_orders_policy_before_gaps
    envelope = policy_envelope.merge("requirements" => [policy_envelope["requirements"].first.merge(
      "status" => "unavailable", "recovery_action" => "execute required analyzer rspec and re-verify")])
    built = RailVerdict::ReviewPacket.build(outcome: outcome, pr_document: pr_document, policy_envelope: envelope)
    sources = built["deterministic"]["recovery"].map { |entry| entry["source"] }
    assert sources.first.start_with?("policy:")
    assert sources.any? { |source| source.start_with?("evidence:") }
  end

  def test_packet_requires_configuration
    bad = FakeOutcome.new(outcome.result, nil)
    assert_raises(RailVerdict::Error) do
      RailVerdict::ReviewPacket.build(outcome: bad, pr_document: pr_document, policy_envelope: policy_envelope)
    end
  end

  def state_binding
    { "head" => "a" * 40, "configuration_digest" => "d" * 64, "policy_digest" => "e" * 64 }
  end

  def observation(author: "human", **kwargs)
    args = { author: author, confidence: "medium", state_binding: state_binding,
             observations: [{ "summary" => "looks fine", "paths" => ["app/models/x.rb"] }] }.merge(kwargs)
    RailVerdict::ReviewObservation.build(**args)
  end

  def test_observation_build_marks_non_authoritative
    doc = observation
    assert_equal false, doc["authoritative"]
    assert_match(/\Asha256:[0-9a-f]{64}\z/, doc["observation_id"])
    assert_empty RailVerdict::SchemaValidator.validate_review_observation(doc)
  end

  def test_observation_human_forbids_provider
    assert_raises(RailVerdict::Error) do
      observation(provider: "acme")
    end
  end

  def test_observation_agent_requires_provider
    assert_raises(RailVerdict::Error) do
      RailVerdict::ReviewObservation.build(author: "agent", confidence: "low",
        state_binding: state_binding, observations: [{ "summary" => "x" }])
    end
    doc = observation(author: "agent", provider: "acme-agent")
    assert_equal "acme-agent", doc["provider"]
  end

  def test_validate_binds_fresh_state
    doc = observation
    verdict = RailVerdict::ReviewObservation.validate(observation: doc, current: state_binding)
    assert_equal "valid_bound", verdict["status"]
    assert_equal doc["observation_id"], verdict["observation_id"]
  end

  def test_validate_stale_head_and_moved_policy
    doc = observation
    moved = state_binding.merge("head" => "f" * 40)
    assert_equal "stale", RailVerdict::ReviewObservation.validate(observation: doc, current: moved)["status"]
    drifted = state_binding.merge("policy_digest" => "0" * 64)
    verdict = RailVerdict::ReviewObservation.validate(observation: doc, current: drifted)
    assert_equal "stale", verdict["status"]
    assert_equal "observation_policy_moved", verdict["code"]
  end

  def test_validate_rejects_tampering_and_unknown_authors
    doc = observation
    tampered = doc.merge("confidence" => "high")
    verdict = RailVerdict::ReviewObservation.validate(observation: tampered, current: state_binding)
    assert_equal "invalid", verdict["status"]
    assert_equal "observation_integrity_failed", verdict["code"]

    assert_equal "unavailable",
      RailVerdict::ReviewObservation.validate(observation: doc, current: nil)["status"]
  end

  def test_validate_takes_no_gate_input
    params = RailVerdict::ReviewObservation.method(:validate).parameters.map(&:last)
    assert_equal %i[observation current].sort, params.sort
    refute_includes params, :gate
    refute_includes params, :outcome
  end

  def workflow(packet_doc, decision, gate, observations: [])
    RailVerdict::WorkflowReceipt.build(packet: packet_doc, policy_decision: decision, gate: gate,
      observations: observations)
  end

  def test_workflow_readiness_matrix
    doc = packet
    assert_equal "review_pending", workflow(doc, "REVIEW_REQUIRED", "PASS")["readiness"]
    assert_equal "blocked_by_gate", workflow(doc, "FAIL", "FAIL")["readiness"]
    assert_equal "blocked_by_evidence", workflow(doc, "INCOMPLETE", "INCOMPLETE")["readiness"]
    assert_equal "blocked_by_evidence", workflow(doc, "FAIL", "PASS")["readiness"]
    ready = workflow(doc, "PASS", "PASS")
    assert_equal "ready", ready["readiness"]
    assert_match(/\Asha256:[0-9a-f]{64}\z/, ready["workflow_receipt_id"])
    assert_empty RailVerdict::SchemaValidator.validate_workflow_receipt(ready)
  end

  def test_workflow_records_observation_bindings_without_bodies
    doc = packet
    obs = observation(author: "agent", provider: "acme")
    verdict = RailVerdict::ReviewObservation.validate(observation: obs, current: state_binding)
    receipt = workflow(doc, "PASS", "PASS",
      observations: [{ "observation_id" => verdict["observation_id"], "author" => "agent", "binding" => verdict["status"] }])
    assert_equal "ready", receipt["readiness"]
    entry = receipt["observations"].first
    assert_equal verdict["observation_id"], entry["observation_id"]
    assert_equal "valid_bound", entry["binding"]
    refute entry.key?("summary")
  end

  def test_workflow_stale_observation_never_upgrades_readiness
    doc = packet
    receipt = workflow(doc, "REVIEW_REQUIRED", "PASS",
      observations: [{ "observation_id" => "sha256:#{'0' * 64}", "author" => "human", "binding" => "stale" }])
    assert_equal "review_pending", receipt["readiness"]
  end
end
