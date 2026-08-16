# frozen_string_literal: true

require_relative "test_helper"

class TestGateResult < Minitest::Test
  def analyzer(status: "succeeded")
    return RailVerdict::AnalyzerResult.new(
      analyzer: "rubocop",
      tool_version: "1.88.0",
      invocation: { "executable" => "rubocop", "argv" => ["--format", "json"] },
      execution_status: "succeeded",
      finding_ids: []
    ) if status == "succeeded"

    RailVerdict::AnalyzerResult.new(
      analyzer: "rubocop",
      invocation: { "executable" => "rubocop", "argv" => ["--format", "json"] },
      execution_status: status,
      finding_ids: [],
      failure: { "code" => status, "message" => "synthetic #{status}" }
    )
  end

  def summary(blocking: false)
    {
      "id" => "rv:#{'a' * 20}",
      "fingerprint" => "sha256:#{'a' * 64}",
      "severity" => "low",
      "state" => "observed",
      "blocking" => blocking
    }
  end

  def test_complete_result_matches_result_schema
    result = RailVerdict::GateResult.new(
      completion_status: "complete",
      gate: "PASS",
      policy_status: "pass",
      findings: [],
      analyzer_results: [analyzer],
      operational_failures: [],
      decision_reasons: [{ "code" => "no_findings_detected", "message" => "No findings." }]
    )
    assert_empty RailVerdict::SchemaValidator.validate_result(result.to_schema_h)
    assert result.frozen?
    assert result.analyzer_results.frozen?
  end

  def test_incomplete_result_requires_operational_failure
    result = RailVerdict::GateResult.new(
      completion_status: "incomplete",
      gate: "INCOMPLETE",
      policy_status: "not_evaluated",
      findings: [summary],
      analyzer_results: [analyzer(status: "failed")],
      operational_failures: [{ "code" => "failed", "analyzer" => "rubocop", "message" => "failed" }],
      decision_reasons: [{ "code" => "required_evidence_incomplete", "message" => "Evidence incomplete." }]
    )
    assert_empty RailVerdict::SchemaValidator.validate_result(result.to_schema_h)
  end

  def test_incomplete_coupling_is_enforced
    assert_raises(ArgumentError) do
      RailVerdict::GateResult.new(
        completion_status: "incomplete",
        gate: "PASS",
        policy_status: "pass",
        findings: [],
        analyzer_results: [analyzer(status: "failed")],
        operational_failures: [],
        decision_reasons: []
      )
    end
  end

  def test_complete_coupling_is_enforced
    assert_raises(ArgumentError) do
      RailVerdict::GateResult.new(
        completion_status: "complete",
        gate: "INCOMPLETE",
        policy_status: "not_evaluated",
        findings: [],
        analyzer_results: [],
        operational_failures: [{ "code" => "failed", "message" => "failed" }],
        decision_reasons: []
      )
    end
  end
end
