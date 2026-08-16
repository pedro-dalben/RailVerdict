# frozen_string_literal: true

require_relative "test_helper"

class TestAnalyzerResult < Minitest::Test
  INVOCATION = { "executable" => "rubocop", "argv" => ["--format", "json"] }.freeze

  def succeeded
    RailVerdict::AnalyzerResult.new(
      analyzer: "rubocop",
      tool_version: "1.88.0",
      invocation: INVOCATION,
      execution_status: "succeeded",
      finding_ids: ["rv:123"]
    )
  end

  def failed(status)
    RailVerdict::AnalyzerResult.new(
      analyzer: "rubocop",
      invocation: INVOCATION,
      execution_status: status,
      finding_ids: [],
      failure: { "code" => status, "message" => "synthetic #{status}" }
    )
  end

  def test_success_is_complete_and_has_no_failure
    result = succeeded
    assert result.complete?
    assert_equal "complete", result.evidence_status
    assert_nil result.failure
    assert result.frozen?
    assert result.invocation.frozen?
    assert result.invocation.fetch("argv").frozen?
  end

  def test_all_failure_statuses_are_incomplete
    RailVerdict::AnalyzerResult::FAILURE_CODES.each do |status|
      result = failed(status)
      refute result.complete?
      assert_equal "incomplete", result.evidence_status
      assert_equal status, result.failure.fetch("code")
    end
  end

  def test_success_cannot_carry_failure
    assert_raises(ArgumentError) do
      RailVerdict::AnalyzerResult.new(
        analyzer: "rubocop",
        invocation: INVOCATION,
        execution_status: "succeeded",
        finding_ids: [],
        failure: { "code" => "failed", "message" => "bad" }
      )
    end
  end

  def test_failure_requires_matching_failure_code
    assert_raises(ArgumentError) do
      RailVerdict::AnalyzerResult.new(
        analyzer: "rubocop",
        invocation: INVOCATION,
        execution_status: "failed",
        finding_ids: [],
        failure: { "code" => "parse_failed", "message" => "bad" }
      )
    end
  end

  def test_schema_hash_preserves_contract_fields
    hash = succeeded.to_schema_h
    assert_equal %w[analyzer tool_version invocation execution_status evidence_status finding_ids], hash.keys
    assert_equal "rubocop", hash.fetch("analyzer")
    assert_equal "1.88.0", hash.fetch("tool_version")
  end
end
