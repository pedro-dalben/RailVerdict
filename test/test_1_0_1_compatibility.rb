# frozen_string_literal: true

require "json"
require "rbconfig"
require "tmpdir"

require_relative "test_helper"

class Test101Compatibility < Minitest::Test
  ROOT = RailVerdictTestHelpers::REPOSITORY_ROOT
  RUBY = RbConfig.ruby
  STUBS = File.join(ROOT, "test", "fixtures", "stubs")

  def with_config(contents)
    Dir.mktmpdir("railverdict-101-") do |dir|
      path = File.join(dir, ".railverdict.yml")
      File.write(path, contents)
      yield dir, path
    end
  end

  def write_tmp_repo(contents)
    Dir.mktmpdir("railverdict-101-repo-") do |dir|
      File.write(File.join(dir, ".railverdict.yml"), contents)
      yield dir
    end
  end

  # --- Timeout: default remains 30 ---

  def test_default_timeout_remains_30
    assert_equal 30, RailVerdict::Configuration::DEFAULT_ANALYZER_TIMEOUT_SECONDS
  end

  def test_old_config_loads_and_defaults_to_30
    with_config(<<~YAML) do |dir, path|
      version: 1.4
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
    YAML
      config = RailVerdict::Configuration.load(path)
      assert_equal 1.4, config.version
      assert_equal 30, config.analyzer_timeout_seconds("rubocop")
      assert_equal 30, config.analyzer_timeout_seconds("rspec")
      assert_equal 30, config.analyzer_timeout_seconds("bundler_audit")
      assert_equal 30, config.analyzer_timeout_seconds("simplecov")
    end
  end

  def test_v1_config_still_loads
    with_config(<<~YAML) do |dir, path|
      version: 1
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
    YAML
      config = RailVerdict::Configuration.load(path)
      assert_equal 1, config.version
      assert_equal 30, config.analyzer_timeout_seconds("rubocop")
    end
  end

  # --- Timeout: configured value accepted ---

  def test_configured_timeout_accepted
    with_config(<<~YAML) do |dir, path|
      version: 1.5
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
        rspec:
          enabled: true
          required: true
          timeout_seconds: 600
        bundler_audit:
          enabled: true
          required: false
          timeout_seconds: 120
    YAML
      config = RailVerdict::Configuration.load(path)
      assert_equal 1.5, config.version
      assert_equal 30, config.analyzer_timeout_seconds("rubocop")
      assert_equal 600, config.analyzer_timeout_seconds("rspec")
      assert_equal 120, config.analyzer_timeout_seconds("bundler_audit")
    end
  end

  def test_simplecov_timeout_accepted
    with_config(<<~YAML) do |dir, path|
      version: 1.5
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
        simplecov:
          enabled: true
          required: false
          timeout_seconds: 60
    YAML
      config = RailVerdict::Configuration.load(path)
      assert_equal 60, config.analyzer_timeout_seconds("simplecov")
    end
  end

  # --- Timeout: invalid values rejected ---

  def test_zero_timeout_rejected
    with_config(<<~YAML) do |dir, path|
      version: 1.5
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
          timeout_seconds: 0
    YAML
      assert_raises(RailVerdict::ConfigurationError) { RailVerdict::Configuration.load(path) }
    end
  end

  def test_negative_timeout_rejected
    with_config(<<~YAML) do |dir, path|
      version: 1.5
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
          timeout_seconds: -5
    YAML
      assert_raises(RailVerdict::ConfigurationError) { RailVerdict::Configuration.load(path) }
    end
  end

  def test_non_integer_timeout_rejected
    with_config(<<~YAML) do |dir, path|
      version: 1.5
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
          timeout_seconds: "600"
    YAML
      assert_raises(RailVerdict::ConfigurationError) { RailVerdict::Configuration.load(path) }
    end
  end

  def test_float_timeout_rejected
    with_config(<<~YAML) do |dir, path|
      version: 1.5
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
          timeout_seconds: 30.5
    YAML
      assert_raises(RailVerdict::ConfigurationError) { RailVerdict::Configuration.load(path) }
    end
  end

  def test_excessive_timeout_rejected
    with_config(<<~YAML) do |dir, path|
      version: 1.5
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
          timeout_seconds: 9999
    YAML
      assert_raises(RailVerdict::ConfigurationError) { RailVerdict::Configuration.load(path) }
    end
  end

  def test_timeout_in_old_version_rejected
    with_config(<<~YAML) do |dir, path|
      version: 1.4
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
          timeout_seconds: 60
    YAML
      assert_raises(RailVerdict::ConfigurationError) { RailVerdict::Configuration.load(path) }
    end
  end

  # --- Timeout: reaches analyzer execution ---

  def test_configured_timeout_reaches_analyzer_execution
    recorder = RecordingRunner.new([
      success_response("rubocop 1.89.0"),
      success_response('{"files":[]}')
    ])
    write_tmp_repo(<<~YAML) do |dir|
      version: 1.5
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
          timeout_seconds: 600
    YAML
      outcome = RailVerdict::Check.execute(
        repository_root: dir,
        config_path: ".railverdict.yml",
        runner: recorder,
        rubocop_command_resolver: ->(_r) { { executable: "rubocop", args_prefix: [] } }
      )
      analyzer_calls = recorder.calls.select { |c| c[:executable] == "rubocop" }
      assert_equal 2, analyzer_calls.length
      assert_equal 600, analyzer_calls[0][:timeout_seconds]
      assert_equal 600, analyzer_calls[1][:timeout_seconds]
    end
  end

  def test_different_analyzers_get_different_timeouts
    recorder = SmartRecordingRunner.new(
      "rubocop" => 10,
      "bundler-audit" => 120,
      "bundle" => 120
    )
    write_tmp_repo(<<~YAML) do |dir|
      version: 1.5
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
          timeout_seconds: 10
        bundler_audit:
          enabled: true
          required: false
          timeout_seconds: 120
    YAML
      outcome = RailVerdict::Check.execute(
        repository_root: dir,
        config_path: ".railverdict.yml",
        runner: recorder,
        rubocop_command_resolver: ->(_r) { { executable: "rubocop", args_prefix: [] } }
      )
      rubocop_calls = recorder.calls.select { |c| c[:executable] == "rubocop" }
      bundle_calls = recorder.calls.select { |c| %w[bundler-audit bundle].include?(c[:executable]) }
      assert_equal 2, rubocop_calls.length
      assert rubocop_calls.all? { |c| c[:timeout_seconds] == 10 }, "rubocop calls should be 10: #{rubocop_calls.inspect}"
      assert_equal 2, bundle_calls.length
      assert bundle_calls.all? { |c| c[:timeout_seconds] == 120 }, "bundler calls should be 120: #{bundle_calls.inspect}"
    end
  end

  def test_missing_timeout_uses_default_30
    recorder = RecordingRunner.new([
      success_response("rubocop 1.89.0"),
      success_response('{"files":[]}')
    ])
    write_tmp_repo(<<~YAML) do |dir|
      version: 1.5
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
    YAML
      outcome = RailVerdict::Check.execute(
        repository_root: dir,
        config_path: ".railverdict.yml",
        runner: recorder,
        rubocop_command_resolver: ->(_r) { { executable: "rubocop", args_prefix: [] } }
      )
      analyzer_calls = recorder.calls.select { |c| c[:executable] == "rubocop" }
      assert_equal 30, analyzer_calls[0][:timeout_seconds]
      assert_equal 30, analyzer_calls[1][:timeout_seconds]
    end
  end

  # --- Timeout: inside succeeds, exceeds is INCOMPLETE ---

  def test_analyzer_completing_inside_timeout_succeeds
    result, _ = bundler_audit_adapter_for("fake_bundler_audit_clean.rb").run(STUBS, timeout_seconds: 2.0)
    assert_equal "succeeded", result.execution_status
    assert_equal "complete", result.evidence_status
  end

  def test_analyzer_exceeding_timeout_is_incomplete
    result, _ = bundler_audit_adapter_for("fake_bundler_audit_slow.rb").run(STUBS, timeout_seconds: 0.3)
    assert_equal "timed_out", result.execution_status
    assert_equal "incomplete", result.evidence_status
  end

  def test_required_timed_out_is_gate_incomplete
    Dir.mktmpdir("railverdict-101-timeout-") do |dir|
      File.write(File.join(dir, ".railverdict.yml"), "version: 1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      timeout_outcome = RailVerdict::Check.execute(
        repository_root: dir,
        config_path: ".railverdict.yml",
        runner: TimeoutRunner.new(timeout_after: 0.05),
        rubocop_command_resolver: ->(_r) { { executable: RUBY, args_prefix: [File.join(STUBS, "fake_rubocop_slow.rb")] } },
        analyzer_timeout_seconds: 0.05
      )
      assert_equal "incomplete", timeout_outcome.result.completion_status
      assert_equal "INCOMPLETE", timeout_outcome.result.gate
      assert_includes timeout_outcome.result.operational_failures.map { |f| f["code"] }, "timed_out"
    end
  end

  def test_per_analyzer_timeout_allows_long_rspec
    recorder = RSpecRecordingRunner.new(examples: [{ "id" => "spec/a_spec.rb[1:1]", "description" => "does something", "full_description" => "A does something", "status" => "passed", "file_path" => "spec/a_spec.rb", "line_number" => 1 }])
    write_tmp_repo(<<~YAML) do |dir|
      version: 1.5
      mode: strict
      analyzers:
        rubocop:
          enabled: false
          required: false
        rspec:
          enabled: true
          required: true
          timeout_seconds: 600
    YAML
      outcome = RailVerdict::Check.execute(
        repository_root: dir,
        config_path: ".railverdict.yml",
        runner: recorder,
        rubocop_command_resolver: ->(_r) { { executable: "bundle", args_prefix: ["exec", "rspec", "--format", "json"] } }
      )
      assert_equal "complete", outcome.result.completion_status
      rspec_calls = recorder.calls.select { |c| %w[bundle rspec].include?(c[:executable]) }
      assert_equal 2, rspec_calls.length
      assert rspec_calls.all? { |c| c[:timeout_seconds] == 600 }, "expected 600: #{rspec_calls.inspect}"
    end
  end

  # --- bundler-audit parsing ---

  def test_bundler_audit_pristine_json
    result, findings = bundler_audit_adapter_for("fake_bundler_audit_clean.rb").run(STUBS, timeout_seconds: 2.0)
    assert_equal "succeeded", result.execution_status
    assert_empty findings
  end

  def test_bundler_audit_prefix_plus_valid_json
    result, findings = bundler_audit_adapter_for("fake_bundler_audit_prefix_json.rb").run(STUBS, timeout_seconds: 2.0)
    assert_equal "succeeded", result.execution_status, result.failure.inspect
    assert_empty findings
  end

  def test_bundler_audit_prefix_plus_vulnerable_json
    result, findings = bundler_audit_adapter_for("fake_bundler_audit_prefix_vulnerable.rb").run(STUBS, timeout_seconds: 2.0)
    assert_equal "succeeded", result.execution_status, result.failure.inspect
    assert_equal 1, findings.length
    assert_equal "bundler_audit", findings.first.analyzer
  end

  def test_bundler_audit_valid_findings_json
    result, findings = bundler_audit_adapter_for("fake_bundler_audit_vulnerable.rb").run(STUBS, timeout_seconds: 2.0)
    assert_equal "succeeded", result.execution_status
    assert_equal 1, findings.length
  end

  def test_bundler_audit_malformed_json_is_parse_failed
    result, _ = bundler_audit_adapter_for("fake_bundler_audit_bad_json.rb").run(STUBS, timeout_seconds: 2.0)
    assert_equal "parse_failed", result.execution_status
    assert_equal "incomplete", result.evidence_status
  end

  def test_bundler_audit_no_json_payload_is_parse_failed
    result, _ = bundler_audit_adapter_for("fake_bundler_audit_no_json.rb").run(STUBS, timeout_seconds: 2.0)
    assert_equal "parse_failed", result.execution_status
  end

  def test_bundler_audit_trailing_garbage_is_parse_failed
    result, _ = bundler_audit_adapter_for("fake_bundler_audit_trailing_garbage.rb").run(STUBS, timeout_seconds: 2.0)
    assert_equal "parse_failed", result.execution_status
  end

  def test_bundler_audit_exit_one_with_valid_json_still_parses
    result, findings = bundler_audit_adapter_for("fake_bundler_audit_vulnerable.rb").run(STUBS, timeout_seconds: 2.0)
    assert_equal "succeeded", result.execution_status
    assert_equal 1, findings.length
  end

  def test_bundler_audit_exit_two_is_command_failure
    result, findings = bundler_audit_adapter_for("fake_bundler_audit_exit2.rb").run(STUBS, timeout_seconds: 2.0)
    assert_equal "failed", result.execution_status
    assert_equal "failed", result.failure.fetch("code")
    assert_empty findings
  end

  def test_bundler_audit_execution_failure_statuses_preserved
    unavailable = RailVerdict::Analyzers::BundlerAudit.new(
      command_resolver: ->(_r) { { executable: "/does/not/exist/bundler-audit", args_prefix: [] } }
    )
    result, _ = unavailable.run(STUBS)
    assert_equal "unavailable", result.execution_status
  end

  private

  def bundler_audit_adapter_for(stub)
    path = File.join(STUBS, stub)
    RailVerdict::Analyzers::BundlerAudit.new(
      command_resolver: ->(_root) { { executable: RUBY, args_prefix: [path] } }
    )
  end

  def success_response(stdout)
    Struct.new(:status, :exit_code, :stdout, :stderr, :stdout_truncated, :stderr_truncated, :detail).new(
      :exited, 0, stdout, "", false, false, nil
    )
  end

  class RecordingRunner
    attr_reader :calls

    def initialize(responses)
      @responses = responses.dup
      @calls = []
    end

    def run(executable, argv, chdir:, timeout_seconds: 30.0, max_stdout_bytes: 4 * 1024 * 1024, max_stderr_bytes: 64 * 1024)
      @calls << { executable: executable, argv: argv, chdir: chdir, timeout_seconds: timeout_seconds }
      resp = @responses.shift
      return resp if resp
      if executable == "git"
        Struct.new(:status, :exit_code, :stdout, :stderr, :stdout_truncated, :stderr_truncated, :detail).new(
          :exited, 0, "abc123def456abc123def456abc123def456abcd", "", false, false, nil
        )
      else
        Struct.new(:status, :exit_code, :stdout, :stderr, :stdout_truncated, :stderr_truncated, :detail).new(
          :exited, 0, '{"files":[]}', "", false, false, nil
        )
      end
    end

    def registry
      @registry ||= Object.new.tap do |r|
        def r.terminate_all; end
      end
    end
  end

  class SmartRecordingRunner
    attr_reader :calls

    def initialize(timeout_map = {})
      @timeout_map = timeout_map
      @calls = []
    end

    def run(executable, argv, chdir:, timeout_seconds: 30.0, max_stdout_bytes: 4 * 1024 * 1024, max_stderr_bytes: 64 * 1024)
      @calls << { executable: executable, argv: argv, chdir: chdir, timeout_seconds: timeout_seconds }
      stdout = case executable
               when "rubocop" then argv.include?("--version") ? "rubocop 1.89.0" : '{"files":[]}'
               when "bundle"
                 if argv.include?("--version")
                   "RSpec 3.13.6"
                 elsif argv.include?("rspec")
                   JSON.generate({ "version" => "3.13.6", "examples" => [], "summary" => { "example_count" => 0, "failure_count" => 0, "pending_count" => 0, "duration" => 0.1 } })
                 elsif argv.include?("bundler-audit")
                   argv.include?("version") ? "bundler-audit 0.9.3" : JSON.generate({ "results" => [] })
                 else
                   '{"files":[]}'
                 end
               when "bundler-audit" then argv.include?("version") ? "bundler-audit 0.9.3" : JSON.generate({ "results" => [] })
               when "rspec" then argv.include?("--version") ? "RSpec 3.13.6" : JSON.generate({ "version" => "3.13.6", "examples" => [], "summary" => { "example_count" => 0, "failure_count" => 0, "pending_count" => 0, "duration" => 0.1 } })
               when "git" then "abc123def456abc123def456abc123def456abcd"
               else '{"files":[]}'
               end
      Struct.new(:status, :exit_code, :stdout, :stderr, :stdout_truncated, :stderr_truncated, :detail).new(
        :exited, 0, stdout, "", false, false, nil
      )
    end

    def registry
      @registry ||= Object.new.tap do |r|
        def r.terminate_all; end
      end
    end
  end

  class TimeoutRunner
    def initialize(timeout_after: 0.05)
      @timeout_after = timeout_after
    end

    def run(executable, argv, chdir:, timeout_seconds: 30.0, max_stdout_bytes: 4 * 1024 * 1024, max_stderr_bytes: 64 * 1024)
      Struct.new(:status, :exit_code, :stdout, :stderr, :stdout_truncated, :stderr_truncated, :detail).new(
        :timed_out, nil, "", "", false, false, "process exceeded the #{timeout_seconds}s monotonic timeout and was terminated"
      )
    end

    def registry
      @registry ||= Object.new.tap do |r|
        def r.terminate_all; end
      end
    end
  end

  class RSpecRecordingRunner
    attr_reader :calls

    def initialize(examples: [])
      @examples = examples
      @calls = []
    end

    def run(executable, argv, chdir:, timeout_seconds: 30.0, max_stdout_bytes: 4 * 1024 * 1024, max_stderr_bytes: 64 * 1024)
      @calls << { executable: executable, argv: argv, chdir: chdir, timeout_seconds: timeout_seconds }
      if executable == "git"
        return Struct.new(:status, :exit_code, :stdout, :stderr, :stdout_truncated, :stderr_truncated, :detail).new(
          :exited, 0, "abc123def456abc123def456abc123def456abcd", "", false, false, nil
        )
      end
      stdout = if argv.include?("--version")
                 "RSpec 3.13.6"
               else
                 JSON.generate({ "version" => "3.13.6", "examples" => @examples, "summary" => { "example_count" => @examples.length, "failure_count" => 0, "pending_count" => 0, "duration" => 0.1 } })
               end
      Struct.new(:status, :exit_code, :stdout, :stderr, :stdout_truncated, :stderr_truncated, :detail).new(
        :exited, 0, stdout, "", false, false, nil
      )
    end

    def registry
      @registry ||= Object.new.tap do |r|
        def r.terminate_all; end
      end
    end
  end
end
