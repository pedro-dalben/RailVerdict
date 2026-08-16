# frozen_string_literal: true

require "json"
require "rbconfig"

require_relative "test_helper"

class TestCheckE2E < Minitest::Test
  ROOT = RailVerdictTestHelpers::REPOSITORY_ROOT
  CLEAN = File.join(ROOT, "test", "fixtures", "rails_clean")
  OFFENSE = File.join(ROOT, "test", "fixtures", "rails_offense")
  STUBS = File.join(ROOT, "test", "fixtures", "stubs")

  def resolver(stub)
    path = File.join(STUBS, stub)
    ->(_root) { { executable: RbConfig.ruby, args_prefix: [path] } }
  end

  def assert_incomplete(outcome, code)
    assert_equal "incomplete", outcome.result.completion_status
    assert_equal "INCOMPLETE", outcome.result.gate
    assert_equal "not_evaluated", outcome.result.policy_status
    assert_includes outcome.result.operational_failures.map { |failure| failure.fetch("code") }, code
    assert_empty RailVerdict::SchemaValidator.validate_result(outcome.result.to_schema_h)
    refute_equal "PASS", outcome.result.gate
  end

  def test_clean_fixture_completes_pass
    outcome = RailVerdict::Check.execute(repository_root: CLEAN, config_path: ".railverdict.yml")
    assert_equal "complete", outcome.result.completion_status
    assert_equal "PASS", outcome.result.gate
    assert_empty outcome.findings
    assert_empty RailVerdict::SchemaValidator.validate_result(outcome.result.to_schema_h)
  end

  def test_offense_fixture_completes_fail_with_findings
    outcome = RailVerdict::Check.execute(repository_root: OFFENSE, config_path: ".railverdict.yml")
    assert_equal "complete", outcome.result.completion_status
    assert_equal "FAIL", outcome.result.gate
    assert_equal 2, outcome.findings.length
    assert_equal outcome.findings.map(&:id), outcome.result.findings.map { |finding| finding.fetch("id") }
  end

  def test_json_result_is_one_document_and_schema_valid
    outcome = RailVerdict::Check.execute(repository_root: OFFENSE, config_path: ".railverdict.yml")
    json = RailVerdict::Reporters::JsonReporter.render(outcome.result)
    assert_equal "\n", json[-1]
    assert_empty RailVerdict::SchemaValidator.validate_result(JSON.parse(json))
  end

  def test_unavailable_required_rubocop_is_incomplete
    outcome = RailVerdict::Check.execute(
      repository_root: CLEAN,
      config_path: ".railverdict.yml",
      rubocop_command_resolver: resolver("does-not-exist.rb")
    )
    assert_incomplete(outcome, "unavailable")
  end

  def test_unsupported_required_rubocop_is_incomplete
    outcome = RailVerdict::Check.execute(
      repository_root: CLEAN,
      config_path: ".railverdict.yml",
      rubocop_command_resolver: resolver("fake_rubocop_old.rb")
    )
    assert_incomplete(outcome, "unsupported")
  end

  def test_malformed_required_rubocop_is_incomplete
    outcome = RailVerdict::Check.execute(
      repository_root: CLEAN,
      config_path: ".railverdict.yml",
      rubocop_command_resolver: resolver("fake_rubocop_bad_json.rb")
    )
    assert_incomplete(outcome, "parse_failed")
  end

  def test_nonzero_required_rubocop_is_incomplete
    outcome = RailVerdict::Check.execute(
      repository_root: CLEAN,
      config_path: ".railverdict.yml",
      rubocop_command_resolver: resolver("fake_rubocop_exit2.rb")
    )
    assert_incomplete(outcome, "failed")
  end

  def test_timeout_required_rubocop_is_incomplete
    outcome = RailVerdict::Check.execute(
      repository_root: CLEAN,
      config_path: ".railverdict.yml",
      rubocop_command_resolver: resolver("fake_rubocop_slow.rb"),
      analyzer_timeout_seconds: 0.25
    )
    assert_incomplete(outcome, "timed_out")
  end

  def test_oversized_required_rubocop_is_incomplete
    outcome = RailVerdict::Check.execute(
      repository_root: CLEAN,
      config_path: ".railverdict.yml",
      rubocop_command_resolver: resolver("fake_rubocop_flood.rb"),
      analyzer_timeout_seconds: 3.0
    )
    assert_incomplete(outcome, "truncated")
  end

  def test_invalid_configuration_never_reaches_analyzer
    with_tmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), "version: 1\nmode: strict\nunknown: true\n")
      outcome = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml")
      assert_incomplete(outcome, "configuration")
      assert_empty outcome.result.analyzer_results
    end
  end
end
