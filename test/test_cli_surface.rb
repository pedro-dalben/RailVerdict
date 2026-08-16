# frozen_string_literal: true

require_relative "test_helper"

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
      assert_includes stderr, "baseline persistence is not implemented in Phase 1"
      assert_includes stderr, "Phase 3"
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

  def test_stub_commands_exit_no_gate_with_diagnostic
    %w[init doctor check findings].each do |command|
      exit_code, stdout, stderr = run_cli([command])
      assert_equal 2, exit_code, "#{command} stub should exit 2"
      assert_empty stdout, "#{command} stub must not write stdout"
      assert_includes stderr, "not yet implemented in this build step"
    end
  end

  def test_contracted_options_parse_without_usage_errors
    exit_code, _stdout, stderr = run_cli(["init", "--config", "custom.yml", "--force"])
    refute_includes stderr, "invalid options"
    assert_equal 2, exit_code
    assert_includes stderr, "not yet implemented"

    exit_code, _stdout, stderr = run_cli(["doctor", "--config", "custom.yml", "--format", "json"])
    assert_equal 2, exit_code
    assert_includes stderr, "not yet implemented"

    exit_code, _stdout, stderr = run_cli(["findings", "--config", "custom.yml", "--format", "json"])
    assert_equal 2, exit_code
    assert_includes stderr, "not yet implemented"
  end
end
