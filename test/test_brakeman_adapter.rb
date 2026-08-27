# frozen_string_literal: true

require "rbconfig"
require_relative "test_helper"

class TestBrakemanAdapter < Minitest::Test
  ROOT = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs")
  RUBY = RbConfig.ruby

  def adapter_for(stub)
    path = File.join(ROOT, stub)
    RailVerdict::Analyzers::Brakeman.new(
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
    result, findings = run_adapter("fake_brakeman_clean.rb")
    assert_equal "succeeded", result.execution_status
    assert_equal "complete", result.evidence_status
    assert_equal "8.0.6", result.tool_version
    assert_empty findings
    assert_equal 0, result.evidence_summary.fetch("security_warnings")
    assert_equal 3, result.evidence_summary.fetch("checks_performed")
    assert_equal "8.0.1", result.evidence_summary.fetch("rails_version")
  end

  def test_warnings_normalize_to_findings
    result, findings = run_adapter("fake_brakeman_warnings.rb")
    assert_equal "succeeded", result.execution_status
    assert_equal 3, findings.length
    assert_equal findings.map(&:sort_key).sort, findings.map(&:sort_key)
    assert_equal findings.map(&:id), result.finding_ids
    assert findings.all? { |f| f.analyzer == "brakeman" && f.origin == "deterministic" }
    assert findings.all? { |f| f.category == "security" }
    
    # Check severity & confidence mappings
    sql = findings.find { |f| f.rule_id == "SQL" }
    assert sql
    assert_equal "high", sql.severity
    assert_equal "high", sql.confidence
    assert_equal "app/models/user.rb", sql.location["path"]
    assert_equal 42, sql.location["start_line"]

    send_file = findings.find { |f| f.rule_id == "SendFile" }
    assert send_file
    assert_equal "medium", send_file.severity
    assert_equal "medium", send_file.confidence

    link_to = findings.find { |f| f.rule_id == "LinkToHref" }
    assert link_to
    assert_equal "low", link_to.severity
    assert_equal "low", link_to.confidence

    assert_empty findings.map { |f| RailVerdict::SchemaValidator.validate_finding(f.to_schema_h) }.flatten
  end

  def test_old_version_is_unsupported
    result, _ = run_adapter("fake_brakeman_old_version.rb")
    assert_equal "unsupported", result.execution_status
    assert_equal "6.0.0", result.tool_version
  end

  def test_garbage_version_is_unsupported
    assert_status("fake_brakeman_garbage_version.rb", "unsupported")
  end

  def test_malformed_json_is_parse_failed
    assert_status("fake_brakeman_bad_json.rb", "parse_failed")
  end

  def test_structural_malformed_outputs_are_malformed
    assert_status("fake_brakeman_malformed.rb", "malformed")
  end

  def test_timeout_is_timed_out
    assert_status("fake_brakeman_slow.rb", "timed_out", timeout_seconds: 0.3)
  end

  def test_oversized_output_is_truncated
    result, findings = run_adapter("fake_brakeman_flood.rb", timeout_seconds: 3.0)
    assert_equal "truncated", result.execution_status
    assert_equal "incomplete", result.evidence_status
    assert_empty findings
  end

  def test_fatal_exit_is_failed
    assert_status("fake_brakeman_exit2.rb", "failed")
  end

  def test_contradiction_exit3_with_0_warnings_is_failed
    assert_status("fake_brakeman_exit3_empty.rb", "failed")
  end

  def test_unavailable_tool_is_incomplete
    adapter = RailVerdict::Analyzers::Brakeman.new(
      command_resolver: ->(_root) { { executable: "non_existent_brakeman_binary_xyz", args_prefix: [] } }
    )
    result, findings = adapter.run(ROOT, timeout_seconds: 1.0)
    assert_equal "unavailable", result.execution_status
    assert_equal "incomplete", result.evidence_status
    assert_empty findings
  end
end
