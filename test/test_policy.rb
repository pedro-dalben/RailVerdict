# frozen_string_literal: true

require_relative "test_helper"

class TestPolicy < Minitest::Test
  FAILURE_STATUSES = RailVerdict::AnalyzerResult::FAILURE_CODES

  def configuration(mode: "strict", required: true, enabled: true)
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict.yml")
      File.write(path, <<~YAML)
        version: 1
        mode: #{mode}
        analyzers:
          rubocop:
            enabled: #{enabled}
            required: #{required}
      YAML
      return RailVerdict::Configuration.load(path)
    end
  end

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

  def finding(path: "app/models/user.rb", line: 4)
    message = "Prefer double quotes"
    fingerprint = RailVerdict::Finding.fingerprint_for(
      analyzer: "rubocop", rule_id: "Style/StringLiterals", path: path, message: message
    )
    RailVerdict::Finding.new(
      fingerprint: fingerprint,
      origin: "deterministic",
      analyzer: "rubocop",
      rule_id: "Style/StringLiterals",
      category: "style",
      severity: "low",
      confidence: "high",
      state: "observed",
      evidence_ref: "native:rubocop:test",
      location: { "path" => path, "start_line" => line, "end_line" => line },
      message: message
    )
  end

  def test_every_required_execution_failure_is_incomplete_and_never_passes
    FAILURE_STATUSES.each do |status|
      result = RailVerdict::Verification::Policy.evaluate(
        configuration: configuration,
        analyzer_results: [analyzer(status: status)],
        findings: []
      )
      assert_equal "incomplete", result.completion_status, status
      assert_equal "INCOMPLETE", result.gate, status
      assert_equal "not_evaluated", result.policy_status, status
      refute_includes %w[PASS WARN FAIL], result.gate
      refute_empty result.operational_failures
    end
  end

  def test_required_analyzer_missing_result_is_incomplete
    result = RailVerdict::Verification::Policy.evaluate(
      configuration: configuration,
      analyzer_results: [],
      findings: []
    )
    assert_equal "INCOMPLETE", result.gate
    assert_equal "unavailable", result.operational_failures.first.fetch("code")
  end

  def test_advisory_findings_warn_without_blocking
    result = RailVerdict::Verification::Policy.evaluate(
      configuration: configuration(mode: "advisory"),
      analyzer_results: [analyzer],
      findings: [finding]
    )
    assert_equal "complete", result.completion_status
    assert_equal "WARN", result.gate
    assert_equal "warn", result.policy_status
    refute result.findings.first.fetch("blocking")
  end

  def test_advisory_without_findings_passes
    result = RailVerdict::Verification::Policy.evaluate(
      configuration: configuration(mode: "advisory"),
      analyzer_results: [analyzer],
      findings: []
    )
    assert_equal "PASS", result.gate
    assert_equal "pass", result.policy_status
  end

  def test_strict_findings_fail_and_block
    result = RailVerdict::Verification::Policy.evaluate(
      configuration: configuration(mode: "strict"),
      analyzer_results: [analyzer],
      findings: [finding]
    )
    assert_equal "FAIL", result.gate
    assert_equal "fail", result.policy_status
    assert result.findings.first.fetch("blocking")
  end

  def test_no_new_debt_is_strict_without_baseline
    result = RailVerdict::Verification::Policy.evaluate(
      configuration: configuration(mode: "no_new_debt"),
      analyzer_results: [analyzer],
      findings: [finding]
    )
    assert_equal "FAIL", result.gate
    assert_includes result.decision_reasons.map { |reason| reason.fetch("code") }, "blocking_findings_present"
  end

  def test_optional_failure_completes_but_remains_visible
    result = RailVerdict::Verification::Policy.evaluate(
      configuration: configuration(mode: "advisory", required: false),
      analyzer_results: [analyzer(status: "unavailable")],
      findings: []
    )
    assert_equal "complete", result.completion_status
    assert_equal "PASS", result.gate
    assert_equal "unavailable", result.operational_failures.first.fetch("code")
    assert_includes result.decision_reasons.map { |reason| reason.fetch("code") }, "optional_evidence_unavailable"
  end

  def test_policy_orders_analyzers_and_findings
    first = finding(path: "z.rb", line: 2)
    second = finding(path: "a.rb", line: 1)
    result = RailVerdict::Verification::Policy.evaluate(
      configuration: configuration,
      analyzer_results: [analyzer],
      findings: [first, second]
    )
    assert_equal [second.id, first.id], result.findings.map { |item| item.fetch("id") }
  end
end
