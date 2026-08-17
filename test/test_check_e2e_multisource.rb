# frozen_string_literal: true

require "json"
require "rbconfig"
require "fileutils"

require_relative "test_helper"

class TestCheckE2EMultisource < Minitest::Test
  STUBS = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "stubs")
  RUBY = RbConfig.ruby

  def make_stubs_config(dir, analyzers)
    lines = ["version: 1.1", "mode: strict", "analyzers:"]
    analyzers.each do |name, sel|
      lines << "  #{name}:"
      lines << "    enabled: #{sel.fetch("enabled")}"
      lines << "    required: #{sel.fetch("required")}"
      sel.each do |k, v|
        next if %w[enabled required].include?(k.to_s)

        lines << "    #{k}: #{v.inspect}"
      end
    end
    File.write(File.join(dir, ".railverdict.yml"), lines.join("\n") + "\n")
  end

  def test_all_four_adapters_complete_with_deterministic_output
    with_tmpdir do |dir|
      make_stubs_config(dir, {
        "rubocop" => { "enabled" => true, "required" => true },
        "simplecov" => { "enabled" => true, "required" => true }
      })
      full = File.join(dir, "coverage/coverage.json")
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, JSON.generate(
        "version" => "1.0",
        "timestamp" => Time.now.to_i,
        "command_name" => "Unit Tests",
        "files" => [{ "filename" => "app/models/book.rb", "coverage" => { "lines" => [1, 1, nil, 1] } }]
      ))

      outcome = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml")
      assert_equal "complete", outcome.result.completion_status
      assert_includes %w[PASS FAIL WARN], outcome.result.gate
      assert_empty RailVerdict::SchemaValidator.validate_result(outcome.result.to_schema_h)
      json = RailVerdict::Reporters::JsonReporter.render(outcome.result)
      assert_equal "\n", json[-1]
      assert_empty RailVerdict::SchemaValidator.validate_result(JSON.parse(json))
      console = RailVerdict::Reporters::Console.render(outcome.result)
      assert_includes console, "Gate: #{outcome.result.gate}"
    end
  end

  def test_required_source_failure_is_incomplete_never_pass
    with_tmpdir do |dir|
      make_stubs_config(dir, {
        "rubocop" => { "enabled" => true, "required" => true },
        "minitest" => { "enabled" => true, "required" => true }
      })
      outcome = RailVerdict::Check.execute(
        repository_root: dir,
        config_path: ".railverdict.yml",
        rubocop_command_resolver: ->(_root) { { executable: RUBY, args_prefix: [File.join(STUBS, "fake_rubocop_exit2.rb")] } }
      )
      assert_equal "incomplete", outcome.result.completion_status
      assert_equal "INCOMPLETE", outcome.result.gate
      assert_equal "not_evaluated", outcome.result.policy_status
      refute_equal "PASS", outcome.result.gate
      assert_includes outcome.result.operational_failures.map { |f| f.fetch("code") }, "failed"
    end
  end

  def test_optional_source_failure_still_completes
    with_tmpdir do |dir|
      make_stubs_config(dir, {
        "rubocop" => { "enabled" => true, "required" => false },
        "minitest" => { "enabled" => true, "required" => false }
      })
      stub = File.join(STUBS, "fake_minitest_empty.rb")
      adapter = RailVerdict::Analyzers::Minitest.new(command_resolver: ->(_root) { { executable: RUBY, args_prefix: [stub] } })
      result, findings = adapter.run(dir)
      configuration = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      gate = RailVerdict::Verification::Policy.evaluate(configuration: configuration, analyzer_results: [result], findings: findings)
      assert_equal "complete", gate.completion_status
    end
  end

  def test_required_zero_tests_is_incomplete
    with_tmpdir do |dir|
      make_stubs_config(dir, {
        "rubocop" => { "enabled" => false, "required" => false },
        "minitest" => { "enabled" => true, "required" => true }
      })
      stub = File.join(STUBS, "fake_minitest_empty.rb")
      adapter = RailVerdict::Analyzers::Minitest.new(command_resolver: ->(_root) { { executable: RUBY, args_prefix: [stub] } })
      result, findings = adapter.run(dir)
      configuration = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      gate = RailVerdict::Verification::Policy.evaluate(configuration: configuration, analyzer_results: [result], findings: findings)
      assert_equal "incomplete", gate.completion_status
      assert_includes gate.operational_failures.map { |f| f.fetch("code") }, "incomplete_evidence"
    end
  end

  def test_required_stale_coverage_is_incomplete
    with_tmpdir do |dir|
      make_stubs_config(dir, {
        "rubocop" => { "enabled" => false, "required" => false },
        "simplecov" => { "enabled" => true, "required" => true, "coverage_path" => "coverage/coverage.json" }
      })
      full = File.join(dir, "coverage/coverage.json")
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, JSON.generate(
        "version" => "1.0",
        "timestamp" => 1000000000,
        "command_name" => "Unit Tests",
        "files" => [{ "filename" => "app/models/book.rb", "coverage" => { "lines" => [1, 1] } }]
      ))
      FileUtils.touch(full, mtime: Time.now - 200_000)
      outcome = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml")
      assert_equal "incomplete", outcome.result.completion_status
      assert_includes outcome.result.operational_failures.map { |f| f.fetch("code") }, "incomplete_evidence"
    end
  end

  def test_brakeman_is_not_a_registered_analyzer_and_unknown_key_is_rejected
    refute RailVerdict::Check.registry.key?("brakeman")
    with_tmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), <<~YAML)
        version: 1.1
        mode: strict
        analyzers:
          rubocop:
            enabled: true
            required: true
          brakeman:
            enabled: true
            required: true
      YAML
      assert_raises(RailVerdict::ConfigurationError) do
        RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      end
    end
  end

  def test_console_and_json_are_deterministic
    with_tmpdir do |dir|
      make_stubs_config(dir, {
        "rubocop" => { "enabled" => true, "required" => true }
      })
      outcome1 = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml")
      outcome2 = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml")
      assert_equal outcome1.result.to_schema_h, outcome2.result.to_schema_h
      assert_equal RailVerdict::Reporters::Console.render(outcome1.result), RailVerdict::Reporters::Console.render(outcome2.result)
      assert_equal RailVerdict::Reporters::JsonReporter.render(outcome1.result), RailVerdict::Reporters::JsonReporter.render(outcome2.result)
    end
  end
end
