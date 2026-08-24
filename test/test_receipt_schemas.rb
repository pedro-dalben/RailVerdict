# frozen_string_literal: true

require_relative "test_helper"

class TestReceiptSchemas < Minitest::Test
  def violations(document, schema_validator)
    RailVerdict::SchemaValidator.public_send(schema_validator, document)
  end

  def valid_receipt
    @valid_receipt ||= {
      "schema_version" => "1.0",
      "receipt_id" => "sha256:#{"a" * 64}",
      "railverdict_version" => "1.2.0",
      "environment" => { "ruby_version" => "3.4.5", "analyzer_versions" => { "rubocop" => "1.88.0" } },
      "verification_mode" => "full",
      "changed_scope" => nil,
      "repository_state" => {
        "head" => "#{"b" * 40}",
        "index_digest" => "sha256:#{"c" * 64}",
        "worktree_digest" => "sha256:#{"d" * 64}",
        "configuration_digest" => "sha256:#{"e" * 64}",
        "baseline_digest" => nil,
        "waivers_digest" => nil
      },
      "gate_projection" => {
        "completion_status" => "complete",
        "gate" => "PASS",
        "policy_status" => "pass",
        "findings" => [],
        "analyzer_evidence" => [],
        "operational_failure_codes" => [],
        "decision_reason_codes" => []
      },
      "pr_intelligence" => nil,
      "repair" => nil
    }
  end

  def valid_validation
    {
      "schema_version" => "1.0",
      "status" => "fresh",
      "receipt_id" => "sha256:#{"a" * 64}",
      "reasons" => [],
      "gate" => "PASS",
      "completion_status" => "complete",
      "current_repository_digest" => "sha256:#{"f" * 64}"
    }
  end

  def test_valid_documents_pass
    assert_empty violations(valid_receipt, :validate_receipt)
    assert_empty violations(valid_validation, :validate_receipt_validation)
  end

  def test_receipt_top_level_negatives
    base = valid_receipt

    unknown = Marshal.load(Marshal.dump(base))
    unknown["confidence_score"] = 0.99
    refute_empty violations(unknown, :validate_receipt), "unknown top-level field must be rejected"

    missing = Marshal.load(Marshal.dump(base))
    missing.delete("repository_state")
    refute_empty violations(missing, :validate_receipt)

    bad_id = Marshal.load(Marshal.dump(base))
    bad_id["receipt_id"] = "md5:abcdef"
    refute_empty violations(bad_id, :validate_receipt)

    bad_mode = Marshal.load(Marshal.dump(base))
    bad_mode["verification_mode"] = "agent"
    refute_empty violations(bad_mode, :validate_receipt)
  end

  def test_receipt_nested_negatives
    bad_head = Marshal.load(Marshal.dump(valid_receipt))
    bad_head["repository_state"]["head"] = ""
    refute_empty violations(bad_head, :validate_receipt)

    bad_baseline = Marshal.load(Marshal.dump(valid_receipt))
    bad_baseline["repository_state"]["baseline_digest"] = "not-a-digest"
    refute_empty violations(bad_baseline, :validate_receipt)

    bad_gate = Marshal.load(Marshal.dump(valid_receipt))
    bad_gate["gate_projection"]["gate"] = "MEH"
    refute_empty violations(bad_gate, :validate_receipt)

    unknown_in_projection = Marshal.load(Marshal.dump(valid_receipt))
    unknown_in_projection["gate_projection"]["ai_completion_allowed"] = true
    refute_empty violations(unknown_in_projection, :validate_receipt),
                 "second policy authority fields must not exist in the contract"

    bad_finding = Marshal.load(Marshal.dump(valid_receipt))
    bad_finding["gate_projection"]["findings"] = [{ "id" => "x" }]
    refute_empty violations(bad_finding, :validate_receipt)

    bad_analyzer_evidence = Marshal.load(Marshal.dump(valid_receipt))
    bad_analyzer_evidence["gate_projection"]["analyzer_evidence"] = [{ "analyzer" => "rubocop", "execution_status" => "succeeded" }]
    refute_empty violations(bad_analyzer_evidence, :validate_receipt), "tool_version is required in projection"

    bad_repair = Marshal.load(Marshal.dump(valid_receipt))
    bad_repair["repair"] = { "packet_id" => "sha256:zzz" }
    refute_empty violations(bad_repair, :validate_receipt)

    bad_scope = Marshal.load(Marshal.dump(valid_receipt))
    bad_scope["changed_scope"] = { "merge_base" => "abc" }
    refute_empty violations(bad_scope, :validate_receipt)
  end

  def test_validation_document_negatives
    base = valid_validation

    bad_status = Marshal.load(Marshal.dump(base))
    bad_status["status"] = "probably-fine"
    refute_empty violations(bad_status, :validate_receipt_validation)

    unknown = Marshal.load(Marshal.dump(base))
    unknown["extra"] = true
    refute_empty violations(unknown, :validate_receipt_validation)

    bad_reason = Marshal.load(Marshal.dump(base))
    bad_reason["reasons"] = [""]
    refute_empty violations(bad_reason, :validate_receipt_validation)

    bad_digest = Marshal.load(Marshal.dump(base))
    bad_digest["current_repository_digest"] = "sha256:xyz"
    refute_empty violations(bad_digest, :validate_receipt_validation)
  end
end
