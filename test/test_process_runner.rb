# frozen_string_literal: true

require "json"

require_relative "test_helper"

class TestProcessRunner < Minitest::Test
  STUBS = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs")
  RUBY = RbConfig.ruby

  def run_stub(stub, argv = [], **options)
    RailVerdict::ProcessRunner.run(
      RUBY,
      [File.join(STUBS, stub), *argv],
      chdir: STUBS,
      **options
    )
  end

  def test_clean_exit_captures_both_streams
    result = run_stub("exit_with.rb", ["0", "--stdout", "out-payload", "--stderr", "err-payload"])
    assert_equal :exited, result.status
    assert_equal 0, result.exit_code
    assert_nil result.signal
    assert_equal "out-payload", result.stdout
    assert_equal "err-payload", result.stderr
    refute result.stdout_truncated
    refute result.stderr_truncated
  end

  def test_nonzero_exit_preserves_facts
    result = run_stub("exit_with.rb", ["3", "--stderr", "boom"])
    assert_equal :exited, result.status
    assert_equal 3, result.exit_code
    assert_equal "boom", result.stderr
    refute_empty result.stderr
  end

  def test_spawn_failure_for_missing_executable
    result = RailVerdict::ProcessRunner.run(
      "railverdict-nonexistent-binary", [], chdir: STUBS
    )
    assert_equal :spawn_failed, result.status
    assert_includes result.detail, "Errno::ENOENT"
    assert_empty result.stdout
    refute result.stdout_truncated
  end

  def test_missing_working_directory_raises
    assert_raises(RailVerdict::ProcessRunner::DirectoryError) do
      RailVerdict::ProcessRunner.run(RUBY, ["-e", "exit 0"], chdir: "/nonexistent/railverdict/dir")
    end
  end

  def test_file_as_working_directory_raises
    assert_raises(RailVerdict::ProcessRunner::DirectoryError) do
      RailVerdict::ProcessRunner.run(RUBY, ["-e", "exit 0"], chdir: File.join(STUBS, "sleep_forever.rb"))
    end
  end

  def test_monotonic_timeout_terminates_child_and_reaps
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = run_stub("sleep_forever.rb", [], timeout_seconds: 0.4)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    assert_equal :timed_out, result.status
    assert_includes result.detail, "timeout"
    assert_operator elapsed, :<, 5.0
    assert_equal :spawn_failed,
                 RailVerdict::ProcessRunner.run("railverdict-nonexistent-binary", [], chdir: STUBS).status
  end

  def test_process_group_termination_reaches_grandchild
    result = run_stub("grandchild_sleep.rb", [], timeout_seconds: 0.7)
    assert_equal :timed_out, result.status
    assert_equal 0, RailVerdict::ProcessRunner.registry.size
  end

  def test_stdout_truncation_marks_stream_and_bounds_bytes
    result = run_stub("spam.rb", ["stdout"], timeout_seconds: 3.0, max_stdout_bytes: 4_096)
    assert result.stdout_truncated
    assert_operator result.stdout.bytesize, :<=, 4_096 + 65_536
    assert result.status
  end

  def test_stderr_truncation_is_independent
    result = run_stub("spam.rb", ["stderr"], timeout_seconds: 3.0, max_stderr_bytes: 2_048)
    assert result.stderr_truncated
    refute result.stdout_truncated
    assert_empty result.stdout
  end

  def test_concurrent_drain_captures_large_output_on_both_streams
    big = "payload-" * 8_000
    result = run_stub(
      "exit_with.rb",
      ["0", "--stdout", big, "--stderr", big],
      timeout_seconds: 5.0,
      max_stdout_bytes: 1_048_576,
      max_stderr_bytes: 1_048_576
    )
    assert_equal :exited, result.status
    assert_equal 0, result.exit_code
    assert_equal big, result.stdout
    assert_equal big, result.stderr
  end

  def test_signaled_child_reports_signal
    result = run_stub("self_signal.rb")
    assert_equal :signaled, result.status
    assert_equal "KILL", result.signal
    assert_nil result.exit_code
    assert_includes result.detail, "signal"
  end

  def test_argv_elements_are_delivered_literally
    corpus = [
      "two words",
      "'single'",
      '"double"',
      "$(echo injected)",
      "\`echo injected\`",
      "; rm -rf /",
      "line\nbreak",
      "--looks-like-option",
      "ünïcodé",
      "a|b&c>d<e",
      "$HOME %{ENV} #{'x'}"
    ]
    result = run_stub("echo_argv_json.rb", corpus)
    assert_equal :exited, result.status
    assert_equal 0, result.exit_code
    assert_equal corpus, JSON.parse(result.stdout)
  end

  def test_nul_byte_argv_element_is_rejected
    assert_raises(ArgumentError) do
      RailVerdict::ProcessRunner.run(RUBY, ["-e", "bad\u0000arg"], chdir: STUBS)
    end
  end

  def test_non_string_argv_element_is_rejected
    assert_raises(ArgumentError) do
      RailVerdict::ProcessRunner.run(RUBY, [123], chdir: STUBS)
    end
  end

  def test_spawn_environment_is_minimal_and_deterministic
    env =
      begin
        ENV["RAILVERDICT_TEST_SECRET"] = "must-not-leak"
        ENV["DISPLAY"] = ":0"
        RailVerdict::ProcessRunner.build_env
      ensure
        ENV.delete("RAILVERDICT_TEST_SECRET")
        ENV.delete("DISPLAY")
      end

    assert_nil env["RAILVERDICT_TEST_SECRET"]
    assert_nil env["DISPLAY"]
    assert_equal "C.UTF-8", env.fetch("LC_ALL")
    assert_equal "UTC", env.fetch("TZ")
    kept = env.reject { |_, value| value.nil? }.keys
    allowed = RailVerdict::ProcessRunner::ENV_ALLOWLIST + %w[LC_ALL TZ]
    assert_empty kept - allowed
  end

  def test_child_does_not_see_parent_secrets
    result =
      begin
        ENV["RAILVERDICT_TEST_SECRET"] = "must-not-leak"
        run_stub("env_report.rb")
      ensure
        ENV.delete("RAILVERDICT_TEST_SECRET")
      end

    child_env = JSON.parse(result.stdout)
    refute child_env.key?("RAILVERDICT_TEST_SECRET")
    assert_equal "C.UTF-8", child_env.fetch("LC_ALL")
    assert_equal "UTC", child_env.fetch("TZ")
  end

  def test_invalid_utf8_output_is_scrubbed_not_crashed
    result = RailVerdict::ProcessRunner.run(
      RUBY,
      ["-e", 'STDOUT.write("\xF0\x9F".b)'],
      chdir: STUBS
    )
    assert_equal :exited, result.status
    assert result.stdout.valid_encoding?
    assert_equal Encoding::UTF_8, result.stdout.encoding
  end

  def test_registry_kill_all_terminates_registered_children
    thread = Thread.new do
      run_stub("sleep_forever.rb", [], timeout_seconds: 10.0)
    end
    sleep 0.4
    assert_operator RailVerdict::ProcessRunner.registry.size, :>=, 1

    RailVerdict::ProcessRunner.registry.terminate_all
    result = thread.value

    assert_equal 0, RailVerdict::ProcessRunner.registry.size
    assert_includes %i[signaled timed_out], result.status
  end

  def test_child_is_reaped_after_run
    result = RailVerdict::ProcessRunner.run(RUBY, ["-e", "puts Process.pid"], chdir: STUBS)
    child_pid = result.stdout.strip.to_i
    assert_operator child_pid, :>, 0
    assert_raises(Errno::ECHILD, Errno::ESRCH) { Process.waitpid(child_pid) }
  end

  def test_run_result_struct_is_frozen_semantics
    result = run_stub("exit_with.rb", ["0"])
    assert_kind_of RailVerdict::ProcessRunner::RunResult, result
    assert result.stdout.frozen?
    assert result.stderr.frozen?
  end
end
