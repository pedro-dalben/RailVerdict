# frozen_string_literal: true

require_relative "test_helper"

require "json"

class TestCLISurface < Minitest::Test
  def test_help_prints_contracted_commands_and_exits_zero
    exit_code, stdout, = run_cli(["--help"])
    assert_equal 0, exit_code
    %w[init doctor check baseline findings].each do |command|
      assert_includes stdout, command
    end
  end

  def test_bare_invocation_prints_usage_and_exits_zero
    exit_code, stdout, = run_cli([])
    assert_equal 0, exit_code
    assert_includes stdout, "Usage: railverdict"
  end

  def test_version_prints_identity_and_exits_zero
    exit_code, stdout, = run_cli(["--version"])
    assert_equal 0, exit_code
    assert_equal "railverdict #{RailVerdict::VERSION}\n", stdout
  end

  def test_unknown_command_exits_no_gate
    exit_code, stdout, stderr = run_cli(["explode"])
    assert_equal 2, exit_code
    assert_empty stdout
    assert_includes stderr, "unknown command: explode"
  end

  def test_unknown_option_exits_no_gate
    exit_code, stdout, stderr = run_cli(["check", "--bogus"])
    assert_equal 2, exit_code
    assert_empty stdout
    refute_empty stderr
  end

  def test_unexpected_positional_arguments_are_rejected
    exit_code, _, stderr = run_cli(["check", "extra"])
    assert_equal 2, exit_code
    assert_includes stderr, "unexpected arguments"
  end

  def test_invalid_format_is_rejected
    exit_code, _, stderr = run_cli(["check", "--format", "yaml"])
    assert_equal 2, exit_code
    assert_includes stderr, "invalid --format"
  end

  def test_baseline_create_is_a_pure_deferral_boundary
    with_tmpdir do |dir|
      exit_code, stdout, stderr = run_cli(["baseline", "create", "--config", ".railverdict.yml", "--output", "baseline.json"], working_directory: dir)
      assert_equal 2, exit_code
      assert_empty stdout
      assert_includes stderr, "refusing to create baseline"
      assert_empty Dir.children(dir)
    end
  end

  def test_baseline_without_create_is_usage_error
    exit_code, _, stderr = run_cli(["baseline", "destroy"])
    assert_equal 2, exit_code
    assert_includes stderr, "only `baseline create` exists"
  end

  def test_check_changed_is_a_phase_4_deferral
    exit_code, stdout, stderr = run_cli(["check", "--changed"])
    assert_equal 2, exit_code
    assert_empty stdout
    assert_includes stderr, "Phase 4"
  end

  def test_check_base_is_a_phase_4_deferral
    exit_code, stdout, stderr = run_cli(["check", "--base", "main"])
    assert_equal 2, exit_code
    assert_empty stdout
    assert_includes stderr, "Phase 4"
  end

  def test_init_creates_refuses_and_forces_configuration
    with_tmpdir do |dir|
      exit_code, stdout, stderr = run_cli(["init"], working_directory: dir)
      assert_equal 0, exit_code
      assert_includes stdout, ".railverdict.yml"
      assert_empty stderr
      assert File.file?(File.join(dir, ".railverdict.yml"))

      exit_code, stdout, stderr = run_cli(["init"], working_directory: dir)
      assert_equal 2, exit_code
      assert_empty stdout
      assert_includes stderr, "use --force"

      exit_code, stdout, stderr = run_cli(["init", "--force"], working_directory: dir)
      assert_equal 0, exit_code
      assert_includes stdout, "initialized"
      assert_empty stderr
    end
  end

  def test_doctor_reports_valid_configuration_and_rubocop
    root = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "rails_clean")
    exit_code, stdout, stderr = run_cli(["doctor", "--format", "json"], working_directory: root)
    assert_equal 0, exit_code
    assert_empty stderr
    report = JSON.parse(stdout)
    assert_equal "1.0", report.fetch("doctor")
    assert_equal true, report.fetch("configuration").fetch("valid")
    assert_equal "succeeded", report.fetch("analyzers").fetch("rubocop").fetch("status")
  end

  def test_check_console_maps_pass_and_fail_exits
    clean = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "rails_clean")
    offense = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "rails_offense")

    exit_code, stdout, stderr = run_cli(["check"], working_directory: clean)
    assert_equal 0, exit_code
    assert_empty stderr
    assert_includes stdout, "Gate: PASS"

    exit_code, stdout, stderr = run_cli(["check"], working_directory: offense)
    assert_equal 1, exit_code
    assert_empty stderr
    assert_includes stdout, "Gate: FAIL"
  end

  def test_check_json_is_single_result_document
    root = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "rails_offense")
    exit_code, stdout, stderr = run_cli(["check", "--format", "json"], working_directory: root)
    assert_equal 1, exit_code
    assert_empty stderr
    assert_equal "\n", stdout[-1]
    parsed = JSON.parse(stdout)
    parsed_without_baseline = parsed.reject { |key, _| %w[baseline comparison].include?(key) }
    assert_empty RailVerdict::SchemaValidator.validate_result(parsed_without_baseline)
  end

  def test_findings_json_is_machine_readable
    root = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "rails_offense")
    exit_code, stdout, stderr = run_cli(["findings", "--format", "json"], working_directory: root)
    assert_equal 0, exit_code
    assert_empty stderr
    document = JSON.parse(stdout)
    assert_equal "1.0", document.fetch("schema_version")
    assert_equal 2, document.fetch("findings").length
    document.fetch("findings").each do |finding|
      assert_empty RailVerdict::SchemaValidator.validate_finding(finding)
    end
  end

  def test_invalid_configuration_is_incomplete_json_and_exit_two
    with_tmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), "version: 1\nmode: strict\nunexpected: true\n")
      exit_code, stdout, stderr = run_cli(["check", "--format", "json"], working_directory: dir)
      assert_equal 2, exit_code
      assert_empty stderr
      result = JSON.parse(stdout)
      assert_equal "INCOMPLETE", result.fetch("gate")
      assert_equal "not_evaluated", result.fetch("policy_status")
      assert_equal "configuration", result.fetch("operational_failures").first.fetch("code")
      parsed_without_baseline = result.reject { |key, _| %w[baseline comparison].include?(key) }
      assert_empty RailVerdict::SchemaValidator.validate_result(parsed_without_baseline)
    end
  end

  def test_interrupted_result_maps_to_exit_130
    result = RailVerdict::Verification::Policy.interrupted_result
    cli = RailVerdict::CLI.new(stdout: StringIO.new, stderr: StringIO.new)
    assert_equal 130, cli.send(:exit_code_for, result, interrupted: true)
  end
end
