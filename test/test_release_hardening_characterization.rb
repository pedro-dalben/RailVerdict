# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "json"

class TestReleaseHardeningCharacterization < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("rv-hardening-char-")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
  end

  # RH-01: RSpec stdout pollution breaks stdout JSON parsing
  def test_rspec_stdout_pollution_causes_parse_failure_in_stdout_transport
    noisy_stdout = <<~OUTPUT
      [AUDIT][2026-08-26] Starting test suite
      {"version":"3.13.0","summary":{"duration":0.1,"example_count":1,"failure_count":0,"pending_count":0,"errors":0},"examples":[{"description":"passes","full_description":"passes","status":"passed","file_path":"./spec/sample_spec.rb","line_number":5}]}
      JSON Coverage report generated for RSpec to coverage/coverage.json
    OUTPUT

    fake_runner = Class.new do
      def initialize(stdout)
        @stdout = stdout
      end

      def run(_executable, _argv, chdir:, timeout_seconds:, max_stdout_bytes: nil)
        RailVerdict::ProcessRunner::RunResult.new(
          status: :exited,
          exit_code: 0,
          signal: nil,
          stdout: @stdout,
          stderr: "",
          stdout_truncated: false,
          stderr_truncated: false,
          detail: nil
        )
      end
    end.new(noisy_stdout)

    analyzer = RailVerdict::Analyzers::RSpec.new(command_resolver: ->(_) { { executable: "rspec", args_prefix: [] } })
    probe_res = RailVerdict::Analyzers::RSpec::Probe.new(status: "succeeded", version: "3.13.0")
    result, findings = analyzer.run(@tmpdir, runner: fake_runner, probe_result: probe_res)

    # In current buggy code, this fails with parse_failed because it parses result.stdout
    assert_equal "parse_failed", result.execution_status
    assert_empty findings
  end

  # RH-02: RSpec nonzero exit with 0 failed examples accepted as succeeded (False PASS)
  def test_rspec_nonzero_exit_with_zero_failures_accepted_as_succeeded_in_current_code
    valid_json_zero_failures = JSON.generate({
      "version" => "3.13.0",
      "summary" => { "duration" => 0.1, "example_count" => 2, "failure_count" => 0, "pending_count" => 0, "errors" => 0 },
      "examples" => [
        { "description" => "test1", "status" => "passed", "file_path" => "./spec/sample_spec.rb", "line_number": 5 },
        { "description" => "test2", "status" => "passed", "file_path" => "./spec/sample_spec.rb", "line_number": 10 }
      ]
    })

    fake_runner = Class.new do
      def initialize(stdout)
        @stdout = stdout
      end

      def run(_executable, _argv, chdir:, timeout_seconds:, max_stdout_bytes: nil)
        RailVerdict::ProcessRunner::RunResult.new(
          status: :exited,
          exit_code: 1, # Nonzero exit from RSpec process!
          signal: nil,
          stdout: @stdout,
          stderr: "Failure after suite execution in after(:suite) hook",
          stdout_truncated: false,
          stderr_truncated: false,
          detail: "exit 1"
        )
      end
    end.new(valid_json_zero_failures)

    analyzer = RailVerdict::Analyzers::RSpec.new(command_resolver: ->(_) { { executable: "rspec", args_prefix: [] } })
    probe_res = RailVerdict::Analyzers::RSpec::Probe.new(status: "succeeded", version: "3.13.0")
    result, findings = analyzer.run(@tmpdir, runner: fake_runner, probe_result: probe_res)

    # In current buggy code, exit_code is completely ignored and it returns "succeeded" with 0 findings!
    assert_equal "succeeded", result.execution_status
    assert_empty findings
  end

  # RH-03: Minitest nonzero exit with 0 failed tests accepted as succeeded (False PASS)
  def test_minitest_nonzero_exit_with_zero_failures_accepted_as_succeeded_in_current_code
    valid_reporter_json = JSON.generate({
      "schema_version" => "1.0",
      "runner" => "minitest 5.20.0",
      "seed" => 1234,
      "tests_total" => 1,
      "assertions" => 1,
      "failures" => 0,
      "errors" => 0,
      "skips" => 0,
      "duration_seconds" => 0.05,
      "tests" => [
        { "class_name" => "SampleTest", "method_name" => "test_pass", "status" => "passed", "file" => "test/sample_test.rb", "line" => 5 }
      ]
    })

    fake_runner = Class.new do
      def initialize(reporter_content)
        @reporter_content = reporter_content
      end

      def run(_executable, _argv, chdir:, timeout_seconds:, max_stdout_bytes: nil)
        output_file = ENV["RAILVERDICT_MINITEST_OUTPUT"]
        File.write(output_file, @reporter_content) if output_file
        RailVerdict::ProcessRunner::RunResult.new(
          status: :exited,
          exit_code: 1, # Process failed in at_exit or abort!
          signal: nil,
          stdout: "",
          stderr: "Unhandled exception in at_exit",
          stdout_truncated: false,
          stderr_truncated: false,
          detail: "exit 1"
        )
      end
    end.new(valid_reporter_json)

    analyzer = RailVerdict::Analyzers::Minitest.new(command_resolver: ->(_) { { executable: "ruby", args_prefix: [] } })
    probe_res = RailVerdict::Analyzers::Minitest::Probe.new(status: "succeeded", version: "5.20.0")
    result, findings = analyzer.run(@tmpdir, runner: fake_runner, probe_result: probe_res)

    # In current buggy code, exit_code is ignored and it returns "succeeded" with 0 findings!
    assert_equal "succeeded", result.execution_status
    assert_empty findings
  end

  # RH-04: Minitest resolve_reporter_path queries Gem::Specification.find_all_by_name first
  def test_minitest_reporter_resolves_via_find_all_by_name
    analyzer = RailVerdict::Analyzers::Minitest.new
    path = analyzer.send(:resolve_reporter_path)
    assert File.file?(path)
    assert path.end_with?("railverdict-minitest-reporter.rb")
  end

  # RH-05: SimpleCov native parser accepts version 0.20.0 despite >= 1 declared contract
  def test_simplecov_native_accepts_unsupported_0_20_in_current_code
    native_json = JSON.generate({
      "meta" => { "simplecov_version" => "0.20.0" },
      "coverage" => {
        File.join(@tmpdir, "app/models/user.rb") => { "lines" => [1, 1, 0] }
      },
      "timestamp" => 1700000000
    })
    cov_path = File.join(@tmpdir, "coverage.json")
    File.write(cov_path, native_json)
    File.write(File.join(@tmpdir, ".railverdict.yml"), <<~YAML)
      version: 1.5
      mode: no_new_debt
      analyzers:
        rubocop:
          enabled: false
          required: false
        simplecov:
          enabled: true
          required: true
          coverage_path: coverage.json
    YAML

    analyzer = RailVerdict::Analyzers::SimpleCov.new
    probe_res = analyzer.probe(@tmpdir)

    # In current buggy code, it accepts 0.20.0 as succeeded!
    assert_equal "succeeded", probe_res.status
    assert_equal "0.20.0", probe_res.version
  end

  # RH-06: SimpleCov missing timestamp falls back to Time.now.to_i
  def test_simplecov_missing_timestamp_uses_time_now_in_current_code
    native_json = JSON.generate({
      "meta" => { "simplecov_version" => "1.0.0" },
      "coverage" => {
        File.join(@tmpdir, "app/models/user.rb") => { "lines" => [1, 1] }
      }
      # No timestamp!
    })
    cov_path = File.join(@tmpdir, "coverage.json")
    File.write(cov_path, native_json)
    File.write(File.join(@tmpdir, ".railverdict.yml"), <<~YAML)
      version: 1.5
      mode: no_new_debt
      analyzers:
        rubocop:
          enabled: false
          required: false
        simplecov:
          enabled: true
          required: true
          coverage_path: coverage.json
    YAML

    analyzer = RailVerdict::Analyzers::SimpleCov.new
    t1 = Time.now.to_i
    result, = analyzer.run(@tmpdir)
    cov_doc = result.evidence_summary["_coverage_document"]

    # In current buggy code, timestamp is Time.now.to_i (>= t1)
    assert cov_doc["timestamp"].is_a?(Integer)
    assert_operator cov_doc["timestamp"], :>=, t1
  end

  # RH-07: SimpleCov external path /etc/passwd stripped to "etc/passwd"
  def test_simplecov_external_path_aliased_to_relative_in_current_code
    native_json = JSON.generate({
      "meta" => { "simplecov_version" => "1.0.0" },
      "coverage" => {
        "/etc/passwd" => { "lines" => [1, 1] }
      },
      "timestamp" => 1700000000
    })
    cov_path = File.join(@tmpdir, "coverage.json")
    File.write(cov_path, native_json)
    File.write(File.join(@tmpdir, ".railverdict.yml"), <<~YAML)
      version: 1.5
      mode: no_new_debt
      analyzers:
        rubocop:
          enabled: false
          required: false
        simplecov:
          enabled: true
          required: true
          coverage_path: coverage.json
    YAML

    analyzer = RailVerdict::Analyzers::SimpleCov.new
    result, = analyzer.run(@tmpdir)
    cov_doc = result.evidence_summary["_coverage_document"]
    filenames = cov_doc["files"].map { |f| f["filename"] }

    # In current buggy code, "/etc/passwd" becomes "etc/passwd" and is accepted!
    assert_includes filenames, "etc/passwd"
  end

  # RH-08: SimpleCov configured coverage_path allows external file path
  def test_simplecov_configured_coverage_path_allows_external_file_in_current_code
    outside_dir = Dir.mktmpdir("rv-outside-")
    outside_cov = File.join(outside_dir, "coverage.json")
    File.write(outside_cov, JSON.generate({
      "version" => "1.0.0",
      "timestamp" => 1700000000,
      "files" => []
    }))

    File.write(File.join(@tmpdir, ".railverdict.yml"), <<~YAML)
      version: 1.5
      mode: no_new_debt
      analyzers:
        rubocop:
          enabled: false
          required: false
        simplecov:
          enabled: true
          required: true
          coverage_path: #{outside_cov}
    YAML

    analyzer = RailVerdict::Analyzers::SimpleCov.new
    probe_res = analyzer.probe(@tmpdir)
    # In current buggy code, it reads outside_cov directly and succeeds!
    assert_equal "succeeded", probe_res.status
  ensure
    FileUtils.remove_entry(outside_dir) if outside_dir && File.exist?(outside_dir)
  end

  # RH-09: VerificationEnvironment falls back to global binary when bundle exec fails
  def test_verification_environment_falls_back_to_global_when_bundle_fails_in_current_code
    File.write(File.join(@tmpdir, "Gemfile"), "source https://rubygems.org\n")
    File.write(File.join(@tmpdir, ".railverdict.yml"), <<~YAML)
      version: 1.5
      mode: no_new_debt
      analyzers:
        rubocop:
          enabled: false
          required: false
        rspec:
          enabled: true
          required: true
    YAML

    fake_runner = Class.new do
      def run(executable, argv, chdir:, timeout_seconds:, max_stdout_bytes: nil)
        if executable == "bundle"
          RailVerdict::ProcessRunner::RunResult.new(
            status: :exited,
            exit_code: 7,
            signal: nil,
            stdout: "",
            stderr: "Could not find gem rspec",
            stdout_truncated: false,
            stderr_truncated: false,
            detail: "exit 7"
          )
        else
          RailVerdict::ProcessRunner::RunResult.new(
            status: :exited,
            exit_code: 0,
            signal: nil,
            stdout: "3.13.0\n",
            stderr: "",
            stdout_truncated: false,
            stderr_truncated: false,
            detail: "exit 0"
          )
        end
      end
    end.new

    env = RailVerdict::VerificationEnvironment.capture(repository_root: @tmpdir, runner: fake_runner)

    # In current buggy code, probe_fallback succeeds using global executable!
    assert_equal true, env.available?
    assert_equal "3.13.0", env.analyzer_versions["rspec"]
  end

  # RH-10: resolve_probe_timeout passes 600s suite timeout into probe
  def test_resolve_probe_timeout_leaks_600s_timeout_in_current_code
    File.write(File.join(@tmpdir, ".railverdict.yml"), <<~YAML)
      version: 1.5
      mode: no_new_debt
      analyzers:
        rubocop:
          enabled: false
          required: false
        rspec:
          enabled: true
          required: true
          timeout_seconds: 600
    YAML
    config = RailVerdict::Configuration.load(File.join(@tmpdir, ".railverdict.yml"))

    # In current buggy code, resolve_probe_timeout returns 600
    timeout = RailVerdict::VerificationEnvironment.send(:resolve_probe_timeout, config, "rspec", 5.0)
    assert_equal 600, timeout
  end
end
