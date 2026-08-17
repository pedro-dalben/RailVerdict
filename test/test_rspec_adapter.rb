# frozen_string_literal: true

require "rbconfig"

require_relative "test_helper"

class TestRspecAdapter < Minitest::Test
  ROOT = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs")
  RUBY = RbConfig.ruby

  def adapter_for(stub)
    path = File.join(ROOT, stub)
    RailVerdict::Analyzers::RSpec.new(
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
    result, findings = run_adapter("fake_rspec_clean.rb")
    assert_equal "succeeded", result.execution_status
    assert_equal "complete", result.evidence_status
    assert_equal "3.13.6", result.tool_version
    assert_empty findings
    assert_equal 2, result.evidence_summary.fetch("tests_total")
  end

  def test_failures_normalize_to_findings
    result, findings = run_adapter("fake_rspec_failures.rb")
    assert_equal "succeeded", result.execution_status
    assert_equal 1, findings.length
    assert_equal findings.map(&:sort_key).sort, findings.map(&:sort_key)
    assert_equal findings.map(&:id), result.finding_ids
    assert findings.all? { |f| f.analyzer == "rspec" && f.origin == "deterministic" }
    assert findings.all? { |f| f.category == "test" && f.confidence == "high" }
    assert_empty findings.map { |f| RailVerdict::SchemaValidator.validate_finding(f.to_schema_h) }.flatten
  end

  def test_pending_examples_do_not_produce_findings
    result, findings = run_adapter("fake_rspec_pending.rb")
    assert_equal "succeeded", result.execution_status
    assert_empty findings
    assert_equal 2, result.evidence_summary.fetch("tests_total")
  end

  def test_empty_suite_succeeds_but_is_empty_at_summary_level
    result, findings = run_adapter("fake_rspec_empty.rb")
    assert_equal "succeeded", result.execution_status
    assert_equal 0, result.evidence_summary.fetch("tests_total")
    assert_empty findings
  end

  def test_old_version_is_unsupported
    result, _ = run_adapter("fake_rspec_old_version.rb")
    assert_equal "unsupported", result.execution_status
    assert_equal "3.10.0", result.tool_version
  end

  def test_garbage_version_is_unsupported
    assert_status("fake_rspec_garbage_version.rb", "unsupported")
  end

  def test_malformed_json_is_parse_failed
    assert_status("fake_rspec_bad_json.rb", "parse_failed")
  end

  def test_structural_malformed_outputs_are_malformed
    assert_status("fake_rspec_malformed.rb", "malformed")
  end

  def test_partial_output_is_truncated_or_parse_failed
    result, _ = run_adapter("fake_rspec_partial.rb")
    assert_includes %w[parse_failed malformed truncated], result.execution_status
  end

  def test_timeout_is_timed_out
    assert_status("fake_rspec_slow.rb", "timed_out", timeout_seconds: 0.3)
  end

  def test_oversized_output_is_truncated
    result, findings = run_adapter("fake_rspec_flood.rb", timeout_seconds: 3.0)
    assert_equal "truncated", result.execution_status
    assert_equal "incomplete", result.evidence_status
    assert_empty findings
  end

  def test_unavailable_tool_is_incomplete
    adapter = RailVerdict::Analyzers::RSpec.new(
      command_resolver: ->(_root) { { executable: "/does/not/exist/rspec", args_prefix: [] } }
    )
    result, findings = adapter.run(ROOT)
    assert_equal "unavailable", result.execution_status
    assert_equal "incomplete", result.evidence_status
    assert_empty findings
  end

  def test_supported_version_is_detected
    probe = adapter_for("fake_rspec_clean.rb").probe(ROOT)
    assert_equal "succeeded", probe.status
    assert_equal "3.13.6", probe.version
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
          rspec:
            enabled: true
            required: true
      YAML
      stub = File.join(ROOT, "fake_rspec_empty.rb")
      adapter = RailVerdict::Analyzers::RSpec.new(command_resolver: ->(_root) { { executable: RUBY, args_prefix: [stub] } })
      result, findings = adapter.run(dir)
      configuration = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      gate = RailVerdict::Verification::Policy.evaluate(configuration: configuration, analyzer_results: [result], findings: findings)
      assert_equal "incomplete", gate.completion_status
      assert_equal "INCOMPLETE", gate.gate
      assert_includes gate.operational_failures.map { |f| f.fetch("code") }, "incomplete_evidence"
    end
  end
end
