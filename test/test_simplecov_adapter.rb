# frozen_string_literal: true

require "fileutils"

require_relative "test_helper"

class TestSimplecovAdapter < Minitest::Test
  COVERAGE_DIR = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test", "fixtures", "coverage")

  def adapter
    RailVerdict::Analyzers::SimpleCov.new
  end

  def with_coverage_dir(coverage_json, coverage_path: "coverage/coverage.json")
    with_tmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), <<~YAML)
        version: 1.1
        mode: strict
        analyzers:
          rubocop:
            enabled: false
            required: false
          simplecov:
            enabled: true
            required: true
            coverage_path: #{coverage_path}
      YAML
      if coverage_json
        full = File.join(dir, coverage_path)
        FileUtils.mkdir_p(File.dirname(full))
        if coverage_json.is_a?(String)
          File.binwrite(full, coverage_json)
        else
          File.write(full, JSON.generate(coverage_json))
        end
      end
      yield dir
    end
  end

  def test_fresh_complete_coverage_succeeds
    json = JSON.parse(File.read(File.join(COVERAGE_DIR, "coverage_clean_v1.json")))
    with_coverage_dir(json) do |dir|
      touch_coverage(dir, "coverage/coverage.json")
      result, findings = adapter.run(dir)
      assert_equal "succeeded", result.execution_status
      assert_equal "1.0", result.tool_version
      assert_empty findings
      assert_equal false, result.evidence_summary.fetch("stale")
    end
  end

  def test_empty_coverage_succeeds_with_zero_executable
    json = JSON.parse(File.read(File.join(COVERAGE_DIR, "coverage_empty_v1.json")))
    with_coverage_dir(json) do |dir|
      result, _ = adapter.run(dir)
      assert_equal "succeeded", result.execution_status
      assert_equal 0, result.evidence_summary.fetch("executable_lines")
      assert_equal 100.0, result.evidence_summary.fetch("percent")
    end
  end

  def test_stale_coverage_is_flagged_as_stale
    json = JSON.parse(File.read(File.join(COVERAGE_DIR, "coverage_stale_v1.json")))
    with_coverage_dir(json, coverage_path: "coverage/coverage.json") do |dir|
      FileUtils.touch(File.join(dir, "coverage/coverage.json"), mtime: Time.now - 200_000)
      configuration = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      result, findings = adapter.run(dir, configuration: configuration)
      assert_equal "succeeded", result.execution_status
      assert_equal true, result.evidence_summary.fetch("stale")
      gate = RailVerdict::Verification::Policy.evaluate(configuration: configuration, analyzer_results: [result], findings: findings)
      assert_equal "incomplete", gate.completion_status
      assert_includes gate.operational_failures.map { |f| f.fetch("code") }, "incomplete_evidence"
    end
  end

  def test_missing_file_is_unavailable
    with_coverage_dir(nil) do |dir|
      result, findings = adapter.run(dir)
      assert_equal "unavailable", result.execution_status
      assert_equal "incomplete", result.evidence_status
      assert_empty findings
    end
  end

  def test_unsupported_version_is_unsupported
    json = JSON.parse(File.read(File.join(COVERAGE_DIR, "coverage_unsupported_v1.json")))
    with_coverage_dir(json) do |dir|
      result, _ = adapter.run(dir)
      assert_equal "unsupported", result.execution_status
    end
  end

  def test_malformed_schema_is_malformed
    json = JSON.parse(File.read(File.join(COVERAGE_DIR, "coverage_malformed.json")))
    with_coverage_dir(json) do |dir|
      result, _ = adapter.run(dir)
      assert_equal "malformed", result.execution_status
    end
  end

  def test_invalid_json_is_parse_failed
    with_coverage_dir("not valid json [[[") do |dir|
      result, _ = adapter.run(dir)
      assert_equal "parse_failed", result.execution_status
    end
  end

  def test_invalid_utf8_is_parse_failed
    with_tmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), <<~YAML)
        version: 1.1
        mode: strict
        analyzers:
          rubocop:
            enabled: false
            required: false
          simplecov:
            enabled: true
            required: true
      YAML
      path = File.join(dir, "coverage/coverage.json")
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, "\xFF\xFE invalid utf8")
      result, _ = adapter.run(dir)
      assert_equal "parse_failed", result.execution_status
    end
  end

  def test_optional_stale_is_allowed
    json = JSON.parse(File.read(File.join(COVERAGE_DIR, "coverage_stale_v1.json")))
    with_tmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), <<~YAML)
        version: 1.1
        mode: strict
        analyzers:
          rubocop:
            enabled: false
            required: false
          simplecov:
            enabled: true
            required: false
            coverage_path: coverage/coverage.json
      YAML
      full = File.join(dir, "coverage/coverage.json")
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, JSON.generate(json))
      FileUtils.touch(full, mtime: Time.now - 200_000)
      configuration = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      result, findings = adapter.run(dir, configuration: configuration)
      assert_equal true, result.evidence_summary.fetch("stale")
      gate = RailVerdict::Verification::Policy.evaluate(configuration: configuration, analyzer_results: [result], findings: findings)
      assert_equal "complete", gate.completion_status
    end
  end

  def test_simplecov_native_unsupported_version_rejected
    native_json = {
      "meta" => { "simplecov_version" => "0.20.0" },
      "coverage" => { "app/models/user.rb" => { "lines" => [1, 1, 0] } },
      "timestamp" => 1700000000
    }
    with_coverage_dir(native_json) do |dir|
      probe_res = adapter.probe(dir)
      assert_equal "unsupported", probe_res.status
      result, findings = adapter.run(dir)
      assert_equal "unsupported", result.execution_status
      assert_empty findings
    end
  end

  def test_simplecov_missing_timestamp_uses_deterministic_sentinel_0
    native_json = {
      "meta" => { "simplecov_version" => "1.0.0" },
      "coverage" => { "app/models/user.rb" => { "lines" => [1, 1] } }
    }
    with_coverage_dir(native_json) do |dir|
      result, _ = adapter.run(dir)
      assert_equal "succeeded", result.execution_status
      cov_doc = result.evidence_summary["_coverage_document"]
      assert_equal 0, cov_doc["timestamp"]
    end
  end

  def test_simplecov_external_path_in_coverage_rejected_as_malformed
    native_json = {
      "meta" => { "simplecov_version" => "1.0.0" },
      "coverage" => { "/etc/passwd" => { "lines" => [1, 1] } },
      "timestamp" => 1700000000
    }
    with_coverage_dir(native_json) do |dir|
      result, findings = adapter.run(dir)
      assert_equal "malformed", result.execution_status
      assert_empty findings
    end
  end

  def test_simplecov_configured_coverage_path_escaping_repo_rejected
    with_tmpdir do |dir|
      outside_dir = Dir.mktmpdir("rv-outside-")
      outside_cov = File.join(outside_dir, "coverage.json")
      File.write(outside_cov, JSON.generate({ "version" => "1.0.0", "timestamp" => 1700000000, "files" => [] }))
      File.write(File.join(dir, ".railverdict.yml"), <<~YAML)
        version: 1.1
        mode: strict
        analyzers:
          rubocop: { enabled: false, required: false }
          simplecov: { enabled: true, required: true, coverage_path: #{outside_cov} }
      YAML
      probe_res = adapter.probe(dir)
      assert_equal "malformed", probe_res.status
      result, _ = adapter.run(dir)
      assert_equal "malformed", result.execution_status
    ensure
      FileUtils.remove_entry(outside_dir) if outside_dir && File.exist?(outside_dir)
    end
  end

  private

  def touch_coverage(dir, coverage_path)
    full = File.join(dir, coverage_path)
    FileUtils.touch(full, mtime: Time.now)
  end
end

