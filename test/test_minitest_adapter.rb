# frozen_string_literal: true

require "rbconfig"

require_relative "test_helper"

class TestMinitestAdapter < Minitest::Test
  ROOT = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs")
  RUBY = RbConfig.ruby

  def adapter_for(stub)
    path = File.join(ROOT, stub)
    RailVerdict::Analyzers::Minitest.new(
      command_resolver: ->(_root) { { executable: RUBY, args_prefix: [path] } }
    )
  end

  def run_adapter(stub, timeout_seconds: 2.0)
    adapter_for(stub).run(ROOT, timeout_seconds: timeout_seconds)
  end

  def assert_status(stub, status, timeout_seconds: 2.0)
    result, findings = run_adapter(stub, timeout_seconds: timeout_seconds)
    assert_equal status, result.execution_status, stub
    assert_equal "incomplete", result.evidence_status, stub
    assert_equal status, result.failure.fetch("code")
    assert_empty findings
    [result, findings]
  end

  def test_clean_run_succeeds_with_no_findings
    result, findings = run_adapter("fake_minitest_clean.rb")
    assert_equal "succeeded", result.execution_status
    assert_equal "complete", result.evidence_status
    assert_equal "6.0.6", result.tool_version
    assert_empty findings
    assert_equal 2, result.evidence_summary.fetch("tests_total")
  end

  def test_failures_normalize_to_sorted_deduplicated_findings
    result, findings = run_adapter("fake_minitest_failures.rb")
    assert_equal "succeeded", result.execution_status
    assert_equal 2, findings.length
    assert_equal findings.map(&:sort_key).sort, findings.map(&:sort_key)
    assert_equal findings.map(&:id), result.finding_ids
    assert findings.any? { |f| f.severity == "high" }
    assert findings.any? { |f| f.severity == "critical" }
    assert findings.all? { |f| f.analyzer == "minitest" && f.origin == "deterministic" }
    assert findings.all? { |f| f.category == "test" }
    assert findings.all? { |f| f.confidence == "high" }
    assert_empty findings.map { |f| RailVerdict::SchemaValidator.validate_finding(f.to_schema_h) }.flatten
  end

  def test_empty_suite_succeeds_but_is_incomplete_evidence_at_policy_layer
    result, findings = run_adapter("fake_minitest_empty.rb")
    assert_equal "succeeded", result.execution_status
    assert_equal 0, result.evidence_summary.fetch("tests_total")
    assert_empty findings
  end

  def test_old_version_is_unsupported
    result, _ = run_adapter("fake_minitest_old_version.rb")
    assert_equal "unsupported", result.execution_status
    assert_equal "4.11.0", result.tool_version
  end

  def test_garbage_version_is_unsupported
    assert_status("fake_minitest_garbage_version.rb", "unsupported")
  end

  def test_malformed_json_is_parse_failed
    assert_status("fake_minitest_bad_json.rb", "parse_failed")
  end

  def test_structural_malformed_outputs_are_malformed
    assert_status("fake_minitest_malformed.rb", "malformed")
  end

  def test_nonzero_execution_recorded_as_inline_parse_or_truncated
    result, _ = run_adapter("fake_minitest_exit2.rb")
    assert_includes %w[parse_failed malformed failed], result.execution_status
  end

  def test_timeout_is_timed_out
    assert_status("fake_minitest_slow.rb", "timed_out", timeout_seconds: 0.3)
  end

  def test_oversized_output_is_truncated
    result, findings = run_adapter("fake_minitest_flood.rb", timeout_seconds: 3.0)
    assert_equal "truncated", result.execution_status
    assert_equal "incomplete", result.evidence_status
    assert_empty findings
  end

  def test_partial_output_is_malformed_or_truncated
    result, _ = run_adapter("fake_minitest_partial.rb")
    assert_includes %w[malformed parse_failed truncated], result.execution_status
  end

  def test_unavailable_tool_is_incomplete
    adapter = RailVerdict::Analyzers::Minitest.new(
      command_resolver: ->(_root) { { executable: "/does/not/exist/minitest", args_prefix: [] } }
    )
    result, findings = adapter.run(ROOT)
    assert_equal "unavailable", result.execution_status
    assert_equal "incomplete", result.evidence_status
    assert_empty findings
  end

  def test_supported_version_is_detected
    probe = adapter_for("fake_minitest_clean.rb").probe(ROOT)
    assert_equal "succeeded", probe.status
    assert_equal "6.0.6", probe.version
  end

  def test_evidence_summary_contains_required_fields
    result, = run_adapter("fake_minitest_clean.rb")
    summary = result.evidence_summary
    assert summary.key?("tests_total")
    assert summary.key?("assertions")
    assert summary.key?("failures")
    assert summary.key?("errors")
    assert summary.key?("skips")
    assert summary.key?("duration_seconds")
  end

  def test_required_zero_tests_policy_fails_closed
    with_tmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), <<~YAML)
        version: 1.1
        mode: strict
        analyzers:
          rubocop:
            enabled: false
            required: false
          minitest:
            enabled: true
            required: true
      YAML
      stub = File.join(ROOT, "fake_minitest_empty.rb")
      adapter = RailVerdict::Analyzers::Minitest.new(command_resolver: ->(_root) { { executable: RUBY, args_prefix: [stub] } })
      result, findings = adapter.run(dir)
      configuration = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      gate = RailVerdict::Verification::Policy.evaluate(configuration: configuration, analyzer_results: [result], findings: findings)
      assert_equal "incomplete", gate.completion_status
      assert_equal "INCOMPLETE", gate.gate
      assert_includes gate.operational_failures.map { |f| f.fetch("code") }, "incomplete_evidence"
    end
  end

  def test_optional_zero_tests_is_allowed
    with_tmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), <<~YAML)
        version: 1.1
        mode: strict
        analyzers:
          rubocop:
            enabled: false
            required: false
          minitest:
            enabled: true
            required: false
      YAML
      stub = File.join(ROOT, "fake_minitest_empty.rb")
      adapter = RailVerdict::Analyzers::Minitest.new(command_resolver: ->(_root) { { executable: RUBY, args_prefix: [stub] } })
      result, findings = adapter.run(dir)
      configuration = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      gate = RailVerdict::Verification::Policy.evaluate(configuration: configuration, analyzer_results: [result], findings: findings)
      assert_equal "complete", gate.completion_status
    end
  end
end
