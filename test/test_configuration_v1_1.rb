# frozen_string_literal: true

require_relative "test_helper"

class TestConfigurationV11 < Minitest::Test
  def with_config(contents)
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict.yml")
      File.write(path, contents)
      yield path
    end
  end

  def test_v1_fixture_still_loads_after_v11_introduction
    root = RailVerdictTestHelpers::REPOSITORY_ROOT
    clean = File.join(root, "test", "fixtures", "rails_clean")
    config = RailVerdict::Configuration.load(File.join(clean, ".railverdict.yml"))
    assert_equal 1, config.version
    assert_empty RailVerdict::SchemaValidator.validate_configuration(
      { "version" => 1, "mode" => "strict", "analyzers" => { "rubocop" => { "enabled" => true, "required" => true } } }
    )
  end

  def test_v11_configuration_loads_with_minitest_rspec_simplecov_bundler_audit
    contents = <<~YAML
      version: 1.1
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
        minitest:
          enabled: true
          required: true
        rspec:
          enabled: true
          required: true
        simplecov:
          enabled: true
          required: true
          coverage_path: coverage/coverage.json
          freshness_window_seconds: 3600
        bundler_audit:
          enabled: true
          required: true
    YAML
    with_config(contents) do |path|
      config = RailVerdict::Configuration.load(path)
      assert_equal 1.1, config.version
      assert_equal true, config.analyzer_enabled?("minitest")
      assert_equal true, config.analyzer_enabled?("rspec")
      assert_equal true, config.analyzer_enabled?("simplecov")
      assert_equal true, config.analyzer_enabled?("bundler_audit")
      assert_equal "coverage/coverage.json", config.analyzer_selection("simplecov").fetch("coverage_path")
    end
  end

  def test_unknown_analyzer_key_is_rejected_in_v11
    contents = <<~YAML
      version: 1.1
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
        totally_unknown:
          enabled: true
          required: true
    YAML
    with_config(contents) do |path|
      assert_raises(RailVerdict::ConfigurationError) { RailVerdict::Configuration.load(path) }
    end
  end

  def test_v11_disabled_simplecov_with_freshness_is_rejected
    contents = <<~YAML
      version: 1.1
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
        simplecov:
          enabled: false
          required: true
    YAML
    with_config(contents) do |path|
      error = assert_raises(RailVerdict::ConfigurationError) { RailVerdict::Configuration.load(path) }
      assert_match(/invalid configuration/i, error.message)
    end
  end

  def test_doctor_lists_all_enabled_analyzers
    contents = <<~YAML
      version: 1.1
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
        minitest:
          enabled: true
          required: true
        rspec:
          enabled: false
          required: false
        simplecov:
          enabled: true
          required: true
        bundler_audit:
          enabled: true
          required: false
    YAML
    with_tmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), contents)
      outcome = RailVerdict::Doctor.execute(repository_root: dir, config_path: ".railverdict.yml")
      assert outcome.report["analyzers"].key?("rubocop")
      assert outcome.report["analyzers"].key?("minitest")
      assert outcome.report["analyzers"].key?("rspec")
      assert outcome.report["analyzers"].key?("simplecov")
      assert outcome.report["analyzers"].key?("bundler_audit")
    end
  end

  def test_missing_analyzer_is_not_enabled
    contents = <<~YAML
      version: 1.1
      mode: strict
      analyzers:
        rubocop:
          enabled: true
          required: true
    YAML
    with_config(contents) do |path|
      config = RailVerdict::Configuration.load(path)
      refute config.analyzer_enabled?("minitest")
    end
  end
end
