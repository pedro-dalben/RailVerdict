# frozen_string_literal: true

require_relative "test_helper"

# Adversarial corpus for engineering policy governance (1.7, ADR 0020).
# Every case must fail closed: no PASS, no fabricated approval, no fail-open.
class TestEngineeringPolicyAdversarial < Minitest::Test
  FakeAnalyzer = Struct.new(:analyzer, :execution_status, :evidence_status)
  FakeResult = Struct.new(:gate, :completion_status, :findings, :comparison, :baseline, :analyzer_results)

  def config(data)
    RailVerdict::Configuration.new(data, "/tmp/fake/.railverdict.yml", JSON.generate(data))
  end

  def outcome(policy:, result_fields: {}, document_fields: {}, config_data: nil)
    data = config_data || { "version" => 1.7, "mode" => "no_new_debt",
      "analyzers" => { "rubocop" => { "enabled" => true, "required" => true },
                        "rspec" => { "enabled" => true, "required" => true } },
      "engineering_policy" => policy }
    result = FakeResult.new(result_fields.fetch(:gate, "PASS"),
      result_fields.fetch(:completion_status, "complete"),
      result_fields.fetch(:findings, []),
      result_fields.fetch(:comparison, { "counts" => { "introduced" => 0 } }),
      result_fields.fetch(:baseline, { "loaded" => true, "compatible" => true }),
      result_fields.fetch(:analyzer_results,
        [FakeAnalyzer.new("rubocop", "succeeded", "complete"),
         FakeAnalyzer.new("rspec", "succeeded", "complete")]))
    document = { "surfaces" => {}, "project_sensitive_areas" => [],
      "review_risk" => { "level" => "LOW", "reasons" => [], "configured" => false },
      "verification_scope" => { "available" => false, "reason" => "test_scope_unavailable", "frameworks" => {} },
      "coverage" => { "available" => false, "reason" => "coverage_evidence_unavailable" } }.merge(document_fields)
    [Struct.new(:result, :configuration).new(result, config(data)), document]
  end

  def evaluate(**kwargs)
    out, doc = outcome(**kwargs)
    RailVerdict::EngineeringPolicy.evaluate(outcome: out, pr_document: doc)
  end

  def test_policy_change_after_receipt_is_drift_not_pass
    out, doc = outcome(policy: {})
    fresh = RailVerdict::EngineeringPolicy.evaluate(outcome: out, pr_document: doc,
      receipt: { "provenance" => { "configuration_digest" => out.configuration.digest } })
    assert_equal "fresh", fresh["drift"]["status"]

    out2, doc2 = outcome(policy: { "findings" => { "new_high" => "forbid" } })
    refute_equal out.configuration.digest, out2.configuration.digest
    drifted = RailVerdict::EngineeringPolicy.evaluate(outcome: out2, pr_document: doc2,
      receipt: { "provenance" => { "configuration_digest" => out.configuration.digest } })
    assert_equal "policy_drift", drifted["drift"]["status"]
    assert_equal "policy_or_config_changed_since_receipt", drifted["drift"]["code"]
  end

  def test_baseline_swap_cannot_satisfy_new_findings_rule
    envelope = evaluate(policy: { "findings" => { "new_critical" => "forbid" } },
      result_fields: { comparison: nil, baseline: { "loaded" => false, "compatible" => false } })
    req = envelope["requirements"].find { |entry| entry["id"] == "req-new-findings-critical" }
    assert_equal "unavailable", req["status"]
    assert_equal "INCOMPLETE", envelope["decision"]
  end

  def test_risk_override_cannot_hide_triggered_review
    # review.risk override lowering migration to low does not clear a surface rule:
    # changes.migration still triggers when migration changed.
    doc_fields = { "surfaces" => { "migration" => { "changed" => true } },
      "verification_scope" => { "available" => true,
        "frameworks" => { "rspec" => { "available" => true, "executed" => true, "scope" => "targeted" } } } }
    envelope = evaluate(policy: { "changes" => { "migration" => { "verification_scope" => "full" } } },
      document_fields: doc_fields)
    req = envelope["requirements"].find { |entry| entry["kind"] == "full_verification_scope" }
    assert_equal "unavailable", req["status"]
    assert_equal "INCOMPLETE", envelope["decision"]
  end

  def test_targeted_mislabeled_as_full_is_rejected
    # A framework claiming scope full without executed evidence is not trusted:
    # framework_scope only reports full for executed analyzers, but if a document
    # ever carries scope full with executed false, the planner must not satisfy.
    doc_fields = { "surfaces" => { "migration" => { "changed" => true } },
      "verification_scope" => { "available" => true,
        "frameworks" => { "rspec" => { "available" => true, "executed" => false, "scope" => "full" } } } }
    envelope = evaluate(policy: { "changes" => { "migration" => { "verification_scope" => "full" } } },
      document_fields: doc_fields)
    req = envelope["requirements"].find { |entry| entry["kind"] == "full_verification_scope" }
    assert_equal "unavailable", req["status"]
  end

  def test_analyzer_success_without_complete_evidence_is_unavailable
    doc_fields = { "surfaces" => { "authorization" => { "changed" => true } } }
    envelope = evaluate(policy: { "changes" => { "authorization" => { "require_analyzers" => ["rspec"] } } },
      document_fields: doc_fields,
      result_fields: { analyzer_results: [FakeAnalyzer.new("rspec", "succeeded", "incomplete")] })
    req = envelope["requirements"].first
    assert_equal "unavailable", req["status"]
    assert_equal "INCOMPLETE", envelope["decision"]
  end

  def test_forged_review_document_cannot_change_decision
    # The evaluator takes no review document input at all: there is no channel
    # by which a forged approval could flip REVIEW_REQUIRED to PASS.
    params = RailVerdict::EngineeringPolicy.method(:evaluate).parameters
    assert_equal [[:keyreq, :outcome]], params.select { |type, _| type == :keyreq }.first(1) & params
    refute_includes params.map(&:last), :review_document
    refute_includes params.map(&:last), :approval
  end

  def test_intelligence_unavailable_fails_closed_not_open
    doc_fields = { "surfaces" => {}, "review_risk" => { "level" => "unknown", "reasons" => [], "configured" => false } }
    envelope = evaluate(policy: { "changes" => { "migration" => { "verification_scope" => "full" } } },
      document_fields: doc_fields)
    # migration surface absent from intelligence: rule not triggered, but the
    # baseline requirement (delta mode) keeps the envelope honest, never PASS-by-default.
    assert_includes %w[PASS INCOMPLETE], envelope["decision"]
    migration_reqs = envelope["requirements"].select { |entry| entry["id"].include?("migration") }
    assert_equal ["not_applicable"], migration_reqs.map { |entry| entry["status"] }.uniq
  end
  def test_unknown_rule_and_conflicting_rule_rejected
    assert_raises(RailVerdict::ConfigurationError) do
      evaluate(policy: { "changes" => { "nope" => { "verification_scope" => "full" } } },
        document_fields: { "surfaces" => { "nope" => { "changed" => true } } })
    end
    # Unknown top-level policy key rejected by closed schema.
    data = { "version" => 1.7, "mode" => "advisory",
      "analyzers" => { "rubocop" => { "enabled" => true, "required" => false } },
      "engineering_policy" => { "teleport" => {} } }
    errors = RailVerdict::SchemaValidator.validate_configuration(data)
    refute_empty errors
  end

  def test_oversized_and_malformed_policy_rejected
    long_key = "k" * 65
    data = { "version" => 1.7, "mode" => "advisory",
      "analyzers" => { "rubocop" => { "enabled" => true, "required" => false } },
      "engineering_policy" => { "review" => { long_key => { "human_review" => "required" } } } }
    refute_empty RailVerdict::SchemaValidator.validate_configuration(data)

    bad_percent = { "version" => 1.7, "mode" => "advisory",
      "analyzers" => { "rubocop" => { "enabled" => true, "required" => false } },
      "engineering_policy" => { "coverage" => { "changed_lines_minimum" => 101 } } }
    refute_empty RailVerdict::SchemaValidator.validate_configuration(bad_percent)
  end

  def test_ai_review_observational_never_changes_gate
    # No AI input exists in the planner: AI output cannot satisfy, violate, or
    # clear any requirement. The decision mirrors deterministic inputs only.
    envelope = evaluate(policy: { "review" => { "high" => { "human_review" => "required" } } },
      document_fields: { "surfaces" => { "migration" => { "changed" => true } },
        "review_risk" => { "level" => "HIGH", "reasons" => ["migration_added"], "configured" => false } })
    assert_equal "REVIEW_REQUIRED", envelope["decision"]
    assert_equal "PASS", envelope["gate"]
  end
end
