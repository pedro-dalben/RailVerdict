# frozen_string_literal: true

require "rbconfig"

require_relative "test_helper"

class TestRuboCopAdapter < Minitest::Test
  ROOT = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs")
  RUBY = RbConfig.ruby

  def adapter_for(stub)
    path = File.join(ROOT, stub)
    RailVerdict::Analyzers::RuboCop.new(
      command_resolver: ->(_root) { { executable: RUBY, args_prefix: [path] } }
    )
  end

  def run_adapter(stub, timeout_seconds: 2.0)
    adapter_for(stub).run(ROOT, timeout_seconds: timeout_seconds)
  end

  def assert_status(stub, status, timeout_seconds: 2.0)
    result, findings = run_adapter(stub, timeout_seconds: timeout_seconds)
    assert_equal status, result.execution_status, stub
    assert_equal "incomplete", result.evidence_status
    assert_equal status, result.failure.fetch("code")
    assert_empty findings
    [result, findings]
  end

  def test_clean_run_succeeds_with_no_findings
    result, findings = run_adapter("fake_rubocop_clean.rb")
    assert_equal "succeeded", result.execution_status
    assert_equal "complete", result.evidence_status
    assert_equal "1.88.0", result.tool_version
    assert_empty findings
    assert_equal ["--format", "json"], result.invocation.fetch("argv")[1..]
  end

  def test_offenses_normalize_to_sorted_deduplicated_findings
    result, findings = run_adapter("fake_rubocop_offenses.rb")
    assert_equal "succeeded", result.execution_status
    assert_equal 3, findings.length
    assert_equal findings.map(&:sort_key).sort, findings.map(&:sort_key)
    assert_equal findings.map(&:id), result.finding_ids
    assert_equal %w[low low medium], findings.map(&:severity).sort
    assert findings.all? { |finding| finding.analyzer == "rubocop" && finding.origin == "deterministic" }
    assert findings.all? { |finding| finding.confidence == "high" && finding.state == "observed" }
    assert findings.all? { |finding| finding.evidence_ref.start_with?("native:rubocop:") }
    assert_empty findings.map { |finding| RailVerdict::SchemaValidator.validate_finding(finding.to_schema_h) }.flatten
  end

  def test_shuffled_input_is_canonical
    first_result, first_findings = run_adapter("fake_rubocop_offenses.rb")
    second_result, second_findings = run_adapter("fake_rubocop_offenses.rb")
    assert_equal first_result.finding_ids, second_result.finding_ids
    assert_equal first_findings.map(&:to_schema_h), second_findings.map(&:to_schema_h)
  end

  def test_unavailable_tool_is_incomplete
    adapter = RailVerdict::Analyzers::RuboCop.new(
      command_resolver: ->(_root) { { executable: "/does/not/exist/rubocop", args_prefix: [] } }
    )
    result, findings = adapter.run(ROOT)
    assert_equal "unavailable", result.execution_status
    assert_equal "incomplete", result.evidence_status
    assert_empty findings
  end

  def test_supported_version_is_detected
    probe = adapter_for("fake_rubocop_clean.rb").probe(ROOT)
    assert_equal "succeeded", probe.status
    assert_equal "1.88.0", probe.version
  end

  def test_old_version_is_unsupported
    result, = run_adapter("fake_rubocop_old.rb")
    assert_equal "unsupported", result.execution_status
    assert_equal "0.93.0", result.tool_version
  end

  def test_garbage_version_is_unsupported
    assert_status("fake_rubocop_garbage_version.rb", "unsupported")
  end

  def test_malformed_json_is_parse_failed
    assert_status("fake_rubocop_bad_json.rb", "parse_failed")
  end

  def test_structural_malformed_outputs_are_malformed
    %w[
      fake_rubocop_unknown_severity.rb
      fake_rubocop_absolute_path.rb
      fake_rubocop_missing_files.rb
    ].each do |stub|
      assert_status(stub, "malformed")
    end
  end

  def test_nonzero_execution_is_failed
    assert_status("fake_rubocop_exit2.rb", "failed")
  end

  def test_timeout_is_timed_out
    assert_status("fake_rubocop_slow.rb", "timed_out", timeout_seconds: 0.25)
  end

  def test_signaled_execution_is_signaled
    assert_status("self_signal.rb", "signaled")
  end

  def test_oversized_output_is_truncated
    result, findings = run_adapter("fake_rubocop_flood.rb", timeout_seconds: 3.0)
    assert_equal "truncated", result.execution_status
    assert_equal "incomplete", result.evidence_status
    assert_empty findings
  end

  def test_invocation_prefers_target_bundle_when_gemfile_exists
    with_tmpdir do |dir|
      File.write(File.join(dir, "Gemfile"), "source \"https://rubygems.org\"\n")
      command = adapter_for("fake_rubocop_clean.rb").send(:default_command, dir)
      assert_equal "bundle", command.fetch(:executable)
      assert_equal %w[exec rubocop], command.fetch(:args_prefix)
    end
  end

  def test_invocation_uses_bare_rubocop_without_gemfile
    with_tmpdir do |dir|
      command = adapter_for("fake_rubocop_clean.rb").send(:default_command, dir)
      assert_equal "rubocop", command.fetch(:executable)
      assert_empty command.fetch(:args_prefix)
    end
  end
end
