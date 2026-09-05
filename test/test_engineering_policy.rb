# frozen_string_literal: true

require_relative "test_helper"

class TestEngineeringPolicy < Minitest::Test
  FakeAnalyzer = Struct.new(:analyzer, :execution_status, :evidence_status)
  FakeResult = Struct.new(:gate, :completion_status, :findings, :comparison, :baseline, :analyzer_results)

  def config(data)
    bytes = JSON.generate(data)
    RailVerdict::Configuration.new(data, "/tmp/fake/.railverdict.yml", bytes)
  end

  def base_config(policy = {})
    config(
      "version" => 1.7, "mode" => "no_new_debt",
      "analyzers" => {
        "rubocop" => { "enabled" => true, "required" => true },
        "rspec" => { "enabled" => true, "required" => true },
        "brakeman" => { "enabled" => true, "required" => false }
      },
      "engineering_policy" => policy
    )
  end

  def base_result(overrides = {})
    FakeResult.new(
      overrides.fetch(:gate, "PASS"),
      overrides.fetch(:completion_status, "complete"),
      overrides.fetch(:findings, []),
      overrides.fetch(:comparison, { "counts" => { "introduced" => 0 } }),
      overrides.fetch(:baseline, { "loaded" => true, "compatible" => true }),
      overrides.fetch(:analyzer_results, [
        FakeAnalyzer.new("rubocop", "succeeded", "complete"),
        FakeAnalyzer.new("rspec", "succeeded", "complete")
      ])
    )
  end

  def base_document(overrides = {})
    {
      "surfaces" => { "authorization" => { "changed" => false }, "migration" => { "changed" => false } },
      "project_sensitive_areas" => [],
      "review_risk" => { "level" => "LOW", "reasons" => [], "configured" => false },
      "verification_scope" => { "available" => false, "reason" => "test_scope_unavailable", "frameworks" => {} },
      "coverage" => { "available" => false, "reason" => "coverage_evidence_unavailable" }
    }.merge(overrides)
  end

  def evaluate(policy:, result: nil, document: nil, configuration: nil)
    outcome = Struct.new(:result, :configuration).new(result || base_result, configuration || base_config(policy))
    RailVerdict::EngineeringPolicy.evaluate(outcome: outcome, pr_document: document || base_document)
  end

  def test_no_policy_section_mirrors_gate
    envelope = evaluate(policy: {})
    assert_equal ["req-baseline-compatible"], envelope["requirements"].map { |entry| entry["id"] }
    assert_equal "satisfied", envelope["requirements"].first["status"]
    assert_equal "PASS", envelope["decision"]
    assert_includes envelope["reason_codes"], "engineering_policy_pass"
  end

  def test_old_config_versions_mirror_gate
    data = { "version" => 1, "mode" => "strict",
             "analyzers" => { "rubocop" => { "enabled" => true, "required" => true } } }
    outcome = Struct.new(:result, :configuration).new(base_result, config(data))
    envelope = RailVerdict::EngineeringPolicy.evaluate(outcome: outcome, pr_document: base_document)
    assert_equal ["req-baseline-compatible"], envelope["requirements"].map { |entry| entry["id"] }
    assert_equal "PASS", envelope["decision"]
  end

  def test_gate_fail_without_violations_stays_fail
    envelope = evaluate(policy: {}, result: base_result(gate: "FAIL"))
    assert_equal "FAIL", envelope["decision"]
    assert_includes envelope["reason_codes"], "gate_failed"
  end

  def test_gate_incomplete_forces_incomplete
    envelope = evaluate(policy: {}, result: base_result(gate: "INCOMPLETE", completion_status: "incomplete"))
    assert_equal "INCOMPLETE", envelope["decision"]
  end

  def test_new_critical_forbidden_with_introduced_critical_fails
    findings = [{ "id" => "rubocop:X", "fingerprint" => "a" * 64, "severity" => "critical", "state" => "introduced" }]
    envelope = evaluate(policy: { "findings" => { "new_critical" => "forbid" } },
      result: base_result(findings: findings, comparison: { "counts" => { "introduced" => 1 } }))
    req = envelope["requirements"].find { |entry| entry["id"] == "req-new-findings-critical" }
    assert_equal "violated", req["status"]
    assert_equal "FAIL", envelope["decision"]
  end

  def test_new_high_allowed_or_absent_is_satisfied_or_not_applicable
    envelope = evaluate(policy: { "findings" => { "new_high" => "forbid" } })
    req = envelope["requirements"].find { |entry| entry["id"] == "req-new-findings-high" }
    assert_equal "satisfied", req["status"]
    assert_equal "PASS", envelope["decision"]

    envelope = evaluate(policy: { "findings" => { "new_critical" => "forbid" } })
    unconfigured = envelope["requirements"].find { |entry| entry["id"] == "req-new-findings-high" }
    assert_equal "not_applicable", unconfigured["status"]
  end

  def test_new_findings_without_delta_is_unavailable_fail_closed
    envelope = evaluate(policy: { "findings" => { "new_critical" => "forbid" } },
      result: base_result(comparison: nil, baseline: {}))
    req = envelope["requirements"].find { |entry| entry["id"] == "req-new-findings-critical" }
    assert_equal "unavailable", req["status"]
    assert_equal "INCOMPLETE", envelope["decision"]
    refute_nil req["recovery_action"]
  end

  def test_waived_findings_do_not_count_as_new
    findings = [{ "id" => "rubocop:X", "fingerprint" => "a" * 64, "severity" => "critical", "state" => "waived" }]
    envelope = evaluate(policy: { "findings" => { "new_critical" => "forbid" } },
      result: base_result(findings: findings))
    req = envelope["requirements"].find { |entry| entry["id"] == "req-new-findings-critical" }
    assert_equal "satisfied", req["status"]
  end

  def test_coverage_minimum_boundary
    doc = base_document("coverage" => { "available" => true, "changed_lines_percent" => 85 })
    envelope = evaluate(policy: { "coverage" => { "changed_lines_minimum" => 85 } }, document: doc)
    assert_equal "satisfied", envelope["requirements"].find { |entry| entry["id"] == "req-coverage-changed-lines" }["status"]
    assert_equal "PASS", envelope["decision"]

    doc = base_document("coverage" => { "available" => true, "changed_lines_percent" => 84 })
    envelope = evaluate(policy: { "coverage" => { "changed_lines_minimum" => 85 } }, document: doc)
    assert_equal "violated", envelope["requirements"].find { |entry| entry["id"] == "req-coverage-changed-lines" }["status"]
    assert_equal "FAIL", envelope["decision"]

    envelope = evaluate(policy: { "coverage" => { "changed_lines_minimum" => 85 } })
    assert_equal "unavailable", envelope["requirements"].find { |entry| entry["id"] == "req-coverage-changed-lines" }["status"]
    assert_equal "INCOMPLETE", envelope["decision"]
  end

  def test_required_analyzer_executed_satisfies
    doc = base_document("surfaces" => { "authorization" => { "changed" => true } })
    envelope = evaluate(
      policy: { "changes" => { "authorization" => { "require_analyzers" => %w[rspec brakeman] } } },
      document: doc,
      result: base_result(analyzer_results: [
        FakeAnalyzer.new("rspec", "succeeded", "complete"),
        FakeAnalyzer.new("brakeman", "succeeded", "complete")
      ]))
    by_id = envelope["requirements"].to_h { |entry| [entry["id"], entry["status"]] }
    assert_equal "satisfied", by_id["req-analyzer-rspec-for-authorization"]
    assert_equal "satisfied", by_id["req-analyzer-brakeman-for-authorization"]
    assert_equal "PASS", envelope["decision"]
  end

  def test_required_analyzer_missing_result_is_unavailable
    doc = base_document("surfaces" => { "authorization" => { "changed" => true } })
    envelope = evaluate(
      policy: { "changes" => { "authorization" => { "require_analyzers" => ["rspec"] } } },
      document: doc, result: base_result(analyzer_results: []))
    req = envelope["requirements"].first
    assert_equal "unavailable", req["status"]
    assert_equal "INCOMPLETE", envelope["decision"]
    assert_includes req["reason_codes"], "required_analyzer_incomplete"
  end

  def test_rule_requiring_disabled_analyzer_fails_closed
    data = { "version" => 1.7, "mode" => "advisory",
             "analyzers" => { "rubocop" => { "enabled" => true, "required" => false },
                              "rspec" => { "enabled" => false, "required" => false } },
             "engineering_policy" => { "changes" => { "authorization" => { "require_analyzers" => ["rspec"] } } } }
    doc = base_document("surfaces" => { "authorization" => { "changed" => true } })
    outcome = Struct.new(:result, :configuration).new(base_result, config(data))
    envelope = RailVerdict::EngineeringPolicy.evaluate(outcome: outcome, pr_document: doc)
    req = envelope["requirements"].first
    assert_equal "unavailable", req["status"]
    assert_includes req["reason_codes"], "rule_conflicts_configuration"
    assert_equal "INCOMPLETE", envelope["decision"]
  end

  def test_full_scope_against_targeted_is_unavailable_not_pass
    doc = base_document(
      "surfaces" => { "migration" => { "changed" => true } },
      "verification_scope" => { "available" => true,
        "frameworks" => { "rspec" => { "available" => true, "executed" => true, "scope" => "targeted" } } })
    envelope = evaluate(policy: { "changes" => { "migration" => { "verification_scope" => "full" } } }, document: doc)
    req = envelope["requirements"].find { |entry| entry["kind"] == "full_verification_scope" }
    assert_equal "unavailable", req["status"]
    assert_match(/FULL/, req["recovery_action"])
    assert_equal "INCOMPLETE", envelope["decision"]
  end

  def test_full_scope_executed_satisfies
    doc = base_document(
      "surfaces" => { "migration" => { "changed" => true } },
      "verification_scope" => { "available" => true,
        "frameworks" => { "rspec" => { "available" => true, "executed" => true, "scope" => "full" } } })
    envelope = evaluate(policy: { "changes" => { "migration" => { "verification_scope" => "full" } } }, document: doc)
    req = envelope["requirements"].find { |entry| entry["kind"] == "full_verification_scope" }
    assert_equal "satisfied", req["status"]
  end

  def test_human_review_trigger_is_review_required_not_pass
    doc = base_document(
      "surfaces" => { "migration" => { "changed" => true } },
      "review_risk" => { "level" => "HIGH", "reasons" => ["migration_added"], "configured" => false })
    envelope = evaluate(policy: { "review" => { "high" => { "human_review" => "required" } } }, document: doc)
    req = envelope["requirements"].find { |entry| entry["kind"] == "human_review" }
    assert_equal "review_required", req["status"]
    assert_equal "review", req["classification"]
    assert_equal "REVIEW_REQUIRED", envelope["decision"]
    assert_equal "PASS", envelope["gate"]
  end

  def test_human_review_untriggered_is_not_applicable
    envelope = evaluate(policy: { "review" => { "critical" => { "human_review" => "required" } } })
    req = envelope["requirements"].find { |entry| entry["kind"] == "human_review" }
    assert_equal "not_applicable", req["status"]
    assert_equal "PASS", envelope["decision"]
  end

  def test_unknown_change_key_raises
    outcome = Struct.new(:result, :configuration).new(base_result,
      base_config("changes" => { "teleportation" => { "verification_scope" => "full" } }))
    doc = base_document("surfaces" => { "teleportation" => { "changed" => true } })
    assert_raises(RailVerdict::ConfigurationError) do
      RailVerdict::EngineeringPolicy.evaluate(outcome: outcome, pr_document: doc)
    end
  end

  def test_unknown_review_key_raises
    outcome = Struct.new(:result, :configuration).new(base_result,
      base_config("review" => { "extreme" => { "human_review" => "required" } }))
    assert_raises(RailVerdict::ConfigurationError) do
      RailVerdict::EngineeringPolicy.evaluate(outcome: outcome, pr_document: base_document)
    end
  end

  def test_rule_order_does_not_change_canonical_document
    policy_a = { "review" => { "high" => { "human_review" => "required" } },
                 "findings" => { "new_high" => "forbid" } }
    policy_b = { "findings" => { "new_high" => "forbid" },
                 "review" => { "high" => { "human_review" => "required" } } }
    first = evaluate(policy: policy_a)
    second = evaluate(policy: policy_b)
    assert_equal first["policy_digest"], second["policy_digest"]
    assert_equal first["requirements"], second["requirements"]
    assert_equal first["reason_codes"], second["reason_codes"]
    assert_equal first["decision"], second["decision"]
  end

  def test_envelope_validates_and_round_trips
    envelope = evaluate(policy: { "findings" => { "new_high" => "forbid" },
                                  "review" => { "high" => { "human_review" => "required" } } })
    assert_empty RailVerdict::SchemaValidator.validate_engineering_policy(envelope)
    reparsed = JSON.parse(RailVerdict::CanonicalJSON.generate(envelope))
    assert_empty RailVerdict::SchemaValidator.validate_engineering_policy(reparsed)
    assert_equal envelope["policy_digest"], reparsed["policy_digest"]
  end

  def test_nil_configuration_fails_closed
    outcome = Struct.new(:result, :configuration).new(base_result, nil)
    assert_raises(RailVerdict::Error) do
      RailVerdict::EngineeringPolicy.evaluate(outcome: outcome, pr_document: base_document)
    end
  end

  def test_drift_detection
    cfg = base_config({})
    outcome = Struct.new(:result, :configuration).new(base_result, cfg)
    fresh_receipt = { "provenance" => { "configuration_digest" => cfg.digest } }
    envelope = RailVerdict::EngineeringPolicy.evaluate(outcome: outcome, pr_document: base_document, receipt: fresh_receipt)
    assert_equal "fresh", envelope["drift"]["status"]

    stale_receipt = { "provenance" => { "configuration_digest" => "0" * 64 } }
    envelope = RailVerdict::EngineeringPolicy.evaluate(outcome: outcome, pr_document: base_document, receipt: stale_receipt)
    assert_equal "policy_drift", envelope["drift"]["status"]

    envelope = RailVerdict::EngineeringPolicy.evaluate(outcome: outcome, pr_document: base_document)
    assert_nil envelope["drift"]
  end
end
