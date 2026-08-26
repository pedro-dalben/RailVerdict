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

  # RH-01: RSpec isolated JSON transport via --out succeeds even with noisy stdout
  def test_rspec_stdout_pollution_isolated_via_tempfile_transport
    valid_json = JSON.generate({
      "version" => "3.13.0",
      "summary" => { "duration" => 0.1, "example_count" => 1, "failure_count" => 0, "pending_count" => 0, "errors" => 0 },
      "examples" => [{ "description" => "passes", "full_description" => "passes", "status" => "passed", "file_path" => "./spec/sample_spec.rb", "line_number" => 5 }]
    })
    noisy_stdout = <<~OUTPUT
      [AUDIT][2026-08-26] Starting test suite
      JSON Coverage report generated for RSpec to coverage/coverage.json
    OUTPUT

    fake_runner = Class.new do
      def initialize(stdout, json)
        @stdout = stdout
        @json = json
      end

      def run(_executable, argv, chdir:, timeout_seconds:, max_stdout_bytes: nil)
        out_idx = argv.index("--out")
        if out_idx
          out_path = argv[out_idx + 1]
          File.write(out_path, @json)
        end
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
    end.new(noisy_stdout, valid_json)

    analyzer = RailVerdict::Analyzers::RSpec.new(command_resolver: ->(_) { { executable: "rspec", args_prefix: [] } })
    probe_res = RailVerdict::Analyzers::RSpec::Probe.new(status: "succeeded", version: "3.13.0")
    result, findings = analyzer.run(@tmpdir, runner: fake_runner, probe_result: probe_res)

    assert_equal "succeeded", result.execution_status
    assert_equal "complete", result.evidence_status
    assert_empty findings
    assert_equal 1, result.evidence_summary["tests_total"]
  end

  # RH-02: RSpec nonzero exit with 0 failed examples fails closed (failed)
  def test_rspec_nonzero_exit_with_zero_failures_fails_closed
    valid_json_zero_failures = JSON.generate({
      "version" => "3.13.0",
      "summary" => { "duration" => 0.1, "example_count" => 2, "failure_count" => 0, "pending_count" => 0, "errors" => 0 },
      "examples" => [
        { "description" => "test1", "status" => "passed", "file_path" => "./spec/sample_spec.rb", "line_number" => 5 },
        { "description" => "test2", "status" => "passed", "file_path" => "./spec/sample_spec.rb", "line_number" => 10 }
      ]
    })

    fake_runner = Class.new do
      def initialize(json)
        @json = json
      end

      def run(_executable, argv, chdir:, timeout_seconds:, max_stdout_bytes: nil)
        out_idx = argv.index("--out")
        if out_idx
          out_path = argv[out_idx + 1]
          File.write(out_path, @json)
        end
        RailVerdict::ProcessRunner::RunResult.new(
          status: :exited,
          exit_code: 1, # Nonzero exit from RSpec process!
          signal: nil,
          stdout: "",
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

    assert_equal "failed", result.execution_status
    assert_equal "incomplete", result.evidence_status
    assert_empty findings
  end

  # RH-03: Minitest nonzero exit with 0 failed tests fails closed (failed)
  def test_minitest_nonzero_exit_with_zero_failures_fails_closed
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

    assert_equal "failed", result.execution_status
    assert_equal "incomplete", result.evidence_status
    assert_empty findings
  end

  # RH-04: Minitest resolve_reporter_path binds to current distribution
  def test_minitest_reporter_resolves_from_current_distribution
    analyzer = RailVerdict::Analyzers::Minitest.new
    path = analyzer.send(:resolve_reporter_path)
    assert File.file?(path)
    assert path.end_with?("exe/railverdict-minitest-reporter.rb")
    assert_equal File.expand_path("../exe/railverdict-minitest-reporter.rb", __dir__), path
  end

  # RH-05: SimpleCov rejects 0.20.0 as unsupported (contract >= 1, < 2)
  def test_simplecov_native_rejects_unsupported_0_20
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
    assert_equal "unsupported", probe_res.status
    result, = analyzer.run(@tmpdir)
    assert_equal "unsupported", result.execution_status
  end

  # RH-06: SimpleCov missing timestamp uses deterministic sentinel 0
  def test_simplecov_missing_timestamp_uses_deterministic_sentinel_0
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
    result, = analyzer.run(@tmpdir)
    cov_doc = result.evidence_summary["_coverage_document"]
    assert_equal 0, cov_doc["timestamp"]
  end

  # RH-07: SimpleCov external path /etc/passwd rejected as malformed
  def test_simplecov_external_path_rejected_as_malformed
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
    result, findings = analyzer.run(@tmpdir)
    assert_equal "malformed", result.execution_status
    assert_empty findings
  end

  # RH-08: SimpleCov configured coverage_path escaping repo is rejected
  def test_simplecov_configured_coverage_path_escaping_repo_rejected
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
    assert_equal "malformed", probe_res.status
    result, = analyzer.run(@tmpdir)
    assert_equal "malformed", result.execution_status
  ensure
    FileUtils.remove_entry(outside_dir) if outside_dir && File.exist?(outside_dir)
  end

  # RH-09: VerificationEnvironment marks environment unavailable when bundle exec fails
  def test_verification_environment_unobservable_when_bundle_fails
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
    assert_equal false, env.available?
    assert_match(/analyzer_version_unobservable:rspec/, env.unavailable_reason)
  end

  # RH-10: resolve_probe_timeout clamps probe timeout to 5.0 seconds
  def test_resolve_probe_timeout_clamps_to_five_seconds
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
    timeout = RailVerdict::VerificationEnvironment.send(:resolve_probe_timeout, config, "rspec", 5.0)
    assert_equal 5.0, timeout
  end
end
