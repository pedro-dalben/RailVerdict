# frozen_string_literal: true

require "rbconfig"

require_relative "test_helper"

class TestBundlerAuditAdapter < Minitest::Test
  ROOT = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs")
  RUBY = RbConfig.ruby

  def adapter_for(stub)
    path = File.join(ROOT, stub)
    RailVerdict::Analyzers::BundlerAudit.new(
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
    result, findings = run_adapter("fake_bundler_audit_clean.rb")
    assert_equal "succeeded", result.execution_status
    assert_equal "complete", result.evidence_status
    assert_equal "0.9.3", result.tool_version
    assert_empty findings
    assert_equal 0, result.evidence_summary.fetch("vulnerabilities")
  end

  def test_vulnerable_run_normalizes_to_findings
    result, findings = run_adapter("fake_bundler_audit_vulnerable.rb")
    assert_equal "succeeded", result.execution_status
    assert_equal 1, findings.length
    assert findings.all? { |f| f.analyzer == "bundler_audit" && f.origin == "deterministic" }
    assert findings.all? { |f| f.category == "dependency" }
    assert_equal findings.map(&:id), result.finding_ids
    assert findings.first.message.include?("Nokogiri")
    assert_empty findings.map { |f| RailVerdict::SchemaValidator.validate_finding(f.to_schema_h) }.flatten
  end

  def test_old_version_is_unsupported
    result, _ = run_adapter("fake_bundler_audit_unsupported.rb")
    assert_equal "unsupported", result.execution_status
    assert_equal "0.8.0", result.tool_version
  end

  def test_garbage_version_is_unsupported
    assert_status("fake_bundler_audit_garbage_version.rb", "unsupported")
  end

  def test_bad_json_is_parse_failed
    assert_status("fake_bundler_audit_bad_json.rb", "parse_failed")
  end

  def test_structural_malformed_is_malformed
    assert_status("fake_bundler_audit_malformed.rb", "malformed")
  end

  def test_timeout_is_timed_out
    assert_status("fake_bundler_audit_slow.rb", "timed_out", timeout_seconds: 0.3)
  end

  def test_oversized_output_is_truncated
    result, findings = run_adapter("fake_bundler_audit_flood.rb", timeout_seconds: 3.0)
    assert_equal "truncated", result.execution_status
    assert_equal "incomplete", result.evidence_status
    assert_empty findings
  end

  def test_unavailable_tool_is_incomplete
    adapter = RailVerdict::Analyzers::BundlerAudit.new(
      command_resolver: ->(_root) { { executable: "/does/not/exist/bundler-audit", args_prefix: [] } }
    )
    result, findings = adapter.run(ROOT)
    assert_equal "unavailable", result.execution_status
    assert_equal "incomplete", result.evidence_status
    assert_empty findings
  end

  def test_supported_version_is_detected
    probe = adapter_for("fake_bundler_audit_clean.rb").probe(ROOT)
    assert_equal "succeeded", probe.status
    assert_equal "0.9.3", probe.version
  end

  def test_invocation_never_contains_update
    result, _ = run_adapter("fake_bundler_audit_clean.rb")
    assert_includes result.invocation.fetch("argv"), "check"
    refute_includes result.invocation.fetch("argv"), "update"
  end

  def test_findings_are_sorted_and_deduped
    result, findings = run_adapter("fake_bundler_audit_vulnerable.rb")
    assert_equal findings.map(&:sort_key).sort, findings.map(&:sort_key)
  end
end
