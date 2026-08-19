# frozen_string_literal: true

require "json"

require_relative "test_helper"

class TestReporters < Minitest::Test
  def analyzer(status: "succeeded", findings: [])
    if status == "succeeded"
      return RailVerdict::AnalyzerResult.new(
        analyzer: "rubocop",
        tool_version: "1.88.0",
        invocation: { "executable" => "rubocop", "argv" => ["--format", "json"] },
        execution_status: "succeeded",
        finding_ids: findings.map(&:id)
      )
    end

    RailVerdict::AnalyzerResult.new(
      analyzer: "rubocop",
      invocation: { "executable" => "rubocop", "argv" => ["--format", "json"] },
      execution_status: status,
      finding_ids: [],
      failure: { "code" => status, "message" => "failure\u001b[31m" }
    )
  end

  def finding(path, line, message: "Message")
    fingerprint = RailVerdict::Finding.fingerprint_for(
      analyzer: "rubocop", rule_id: "Style/Foo", path: path, message: message
    )
    RailVerdict::Finding.new(
      fingerprint: fingerprint,
      origin: "deterministic",
      analyzer: "rubocop",
      rule_id: "Style/Foo",
      category: "style",
      severity: "low",
      confidence: "high",
      state: "observed",
      evidence_ref: "native",
      location: { "path" => path, "start_line" => line, "end_line" => line },
      message: message
    )
  end

  def result(findings: [])
    RailVerdict::GateResult.new(
      completion_status: "complete",
      gate: findings.empty? ? "PASS" : "FAIL",
      policy_status: findings.empty? ? "pass" : "fail",
      findings: findings.map do |item|
        {
          "id" => item.id,
          "fingerprint" => item.fingerprint,
          "severity" => item.severity,
          "state" => item.state,
          "blocking" => true
        }
      end,
      analyzer_results: [analyzer(findings: findings)],
      operational_failures: [],
      decision_reasons: [{ "code" => "test", "message" => "Message\u001b[31m" }]
    )
  end

  def test_json_is_one_schema_valid_document
    output = RailVerdict::Reporters::JsonReporter.render(result)
    assert_equal "\n", output[-1]
    parsed = JSON.parse(output)
    assert_empty RailVerdict::SchemaValidator.validate_result(parsed)
    assert_equal output, JSON.generate(parsed) + "\n"
  end

  def test_json_is_deterministic
    first = RailVerdict::Reporters::JsonReporter.render(result(findings: [finding("z.rb", 2), finding("a.rb", 1)]))
    second = RailVerdict::Reporters::JsonReporter.render(result(findings: [finding("z.rb", 2), finding("a.rb", 1)]))
    assert_equal first, second
  end

  def test_console_is_deterministic_and_has_no_ansi
    output = RailVerdict::Reporters::Console.render(result(findings: [finding("app/a.rb", 1, message: "bad\e[31m")]))
    assert_equal output, RailVerdict::Reporters::Console.render(result(findings: [finding("app/a.rb", 1, message: "bad\e[31m")]))
    refute_includes output, "\e["
    assert_includes output, "RailVerdict #{RailVerdict::VERSION}"
    assert_includes output, "Gate: FAIL"
  end

  def test_console_reports_incomplete_operational_failure
    failed = analyzer(status: "failed")
    incomplete = RailVerdict::GateResult.new(
      completion_status: "incomplete",
      gate: "INCOMPLETE",
      policy_status: "not_evaluated",
      findings: [],
      analyzer_results: [failed],
      operational_failures: [{ "code" => "failed", "analyzer" => "rubocop", "message" => "failed\nmessage" }],
      decision_reasons: [{ "code" => "required_evidence_incomplete", "message" => "Not evaluated." }]
    )
    output = RailVerdict::Reporters::Console.render(incomplete)
    assert_includes output, "Gate: INCOMPLETE"
    assert_includes output, "[failed] rubocop: failed message"
  end

  def test_reporter_does_not_add_policy_fields
    parsed = JSON.parse(RailVerdict::Reporters::JsonReporter.render(result))
    refute parsed.key?("run_context")
    refute parsed.fetch("findings").any? { |finding| finding.key?("rule_id") }
  end
end
