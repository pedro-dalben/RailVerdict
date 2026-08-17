# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "fileutils"

class TestBaseline < Minitest::Test
  FIXTURES = File.expand_path("fixtures", __dir__)

  def build_findings(count: 1, prefix: "msg")
    count.times.map do |index|
      message = "#{prefix} #{index}"
      fingerprint = RailVerdict::Finding.fingerprint_for(analyzer: "rubocop", rule_id: "Style/StringLiterals", path: "app/models/user.rb", message: message)
      RailVerdict::Finding.new(
        fingerprint: fingerprint,
        origin: "deterministic",
        analyzer: "rubocop",
        rule_id: "Style/StringLiterals",
        category: "style",
        severity: "low",
        confidence: "high",
        state: "observed",
        evidence_ref: "native:rubocop:#{fingerprint.delete_prefix('sha256:')[0, 12]}",
        location: { "path" => "app/models/user.rb", "start_line" => index + 1, "end_line" => index + 1 },
        message: message
      )
    end
  end

  def configuration_in(dir, content: nil)
    content ||= "version: 1.2\nmode: no_new_debt\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n"
    path = File.join(dir, ".railverdict.yml")
    File.write(path, content)
    RailVerdict::Configuration.load(path)
  end

  def test_valid_baseline_passes_schema
    with_tmpdir do |dir|
      config = configuration_in(dir)
      findings = build_findings(count: 2)
      baseline = RailVerdict::Baseline.create(findings: findings, configuration: config, analyzer_versions: { "rubocop" => "1.89.0" }, clock: Time.utc(2026, 8, 17, 12, 0, 0))
      assert_empty RailVerdict::SchemaValidator.validate_baseline(baseline.to_h)
      assert_equal "1.0", baseline.to_h.fetch("schema_version")
      assert_equal 1, baseline.to_h.fetch("fingerprint_version")
      assert_equal "sha256", baseline.to_h.fetch("algorithm")
      assert_equal 2, baseline.entries.length
      assert baseline.entries.map { |entry| entry.fetch("fingerprint") } == baseline.entries.map { |entry| entry.fetch("fingerprint") }.sort
    end
  end

  def test_baseline_rejects_unknown_fields
    with_tmpdir do |dir|
      config = configuration_in(dir)
      baseline = RailVerdict::Baseline.create(findings: build_findings(count: 1), configuration: config, analyzer_versions: {}, clock: Time.utc(2026, 8, 17, 12, 0, 0))
      hash = baseline.to_h.dup
      hash["source_code"] = "secret"
      assert RailVerdict::SchemaValidator.validate_baseline(hash).any?
    end
  end

  def test_read_round_trip
    with_tmpdir do |dir|
      config = configuration_in(dir)
      baseline = RailVerdict::Baseline.create(findings: build_findings(count: 2), configuration: config, analyzer_versions: { "rubocop" => "1.89.0" }, clock: Time.utc(2026, 8, 17, 12, 0, 0))
      path = File.join(dir, ".railverdict-baseline.json")
      RailVerdict::Baseline.write(path: path, baseline: baseline)
      loaded = RailVerdict::Baseline.read(path)
      assert_equal baseline.to_h, loaded.to_h
    end
  end

  def test_reader_fails_on_corrupted_json
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict-baseline.json")
      File.write(path, "{ not json")
      assert_raises(RailVerdict::Baseline::IncompatibleError) { RailVerdict::Baseline.read(path) }
    end
  end

  def test_reader_fails_on_unknown_schema_version
    with_tmpdir do |dir|
      config = configuration_in(dir)
      baseline = RailVerdict::Baseline.create(findings: build_findings(count: 1), configuration: config, analyzer_versions: {}, clock: Time.utc(2026, 8, 17, 12, 0, 0))
      path = File.join(dir, ".railverdict-baseline.json")
      RailVerdict::Baseline.write(path: path, baseline: baseline)
      hash = JSON.parse(File.read(path))
      hash["schema_version"] = "99.0"
      File.write(path, JSON.generate(hash))
      error = assert_raises(RailVerdict::Baseline::IncompatibleError) { RailVerdict::Baseline.read(path) }
      assert_includes error.message, "re-create with `railverdict baseline create`"
    end
  end

  def test_reader_fails_on_unknown_fingerprint_version
    with_tmpdir do |dir|
      config = configuration_in(dir)
      baseline = RailVerdict::Baseline.create(findings: build_findings(count: 1), configuration: config, analyzer_versions: {}, clock: Time.utc(2026, 8, 17, 12, 0, 0))
      path = File.join(dir, ".railverdict-baseline.json")
      RailVerdict::Baseline.write(path: path, baseline: baseline)
      hash = JSON.parse(File.read(path))
      hash["fingerprint_version"] = 99
      File.write(path, JSON.generate(hash))
      assert_raises(RailVerdict::Baseline::IncompatibleError) { RailVerdict::Baseline.read(path) }
    end
  end

  def test_reader_fails_on_duplicate_fingerprints
    with_tmpdir do |dir|
      config = configuration_in(dir)
      findings = build_findings(count: 1)
      baseline = RailVerdict::Baseline.create(findings: findings, configuration: config, analyzer_versions: {}, clock: Time.utc(2026, 8, 17, 12, 0, 0))
      path = File.join(dir, ".railverdict-baseline.json")
      hash = baseline.to_h.dup
      hash["entries"] = [hash["entries"].first, hash["entries"].first]
      File.write(path, JSON.generate(hash))
      assert_raises(RailVerdict::Baseline::IncompatibleError) { RailVerdict::Baseline.read(path) }
    end
  end

  def test_resolve_path_precedence
    with_tmpdir do |dir|
      config = configuration_in(dir, content: "version: 1.2\nmode: no_new_debt\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\nbaseline:\n  path: custom/baseline.json\n")
      assert_equal File.join(File.realpath(dir), "custom/baseline.json"), RailVerdict::Baseline.resolve_path(repository_root: dir, configuration: config)
      assert_equal "/tmp/override.json", RailVerdict::Baseline.resolve_path(repository_root: dir, configuration: config, output_override: "/tmp/override.json")
    end
  end

  def test_configuration_1_2_loads
    with_tmpdir do |dir|
      config = configuration_in(dir, content: "version: 1.2\nmode: no_new_debt\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\nbaseline:\n  path: .railverdict-baseline.json\nwaivers:\n  path: .railverdict-waivers.json\n")
      assert_equal 1.2, config.version
      assert_equal ".railverdict-baseline.json", config.baseline_path
      assert_equal ".railverdict-waivers.json", config.waivers_path
    end
  end

  def test_configuration_1_1_still_loads
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict.yml")
      File.write(path, "version: 1.1\nmode: no_new_debt\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      config = RailVerdict::Configuration.load(path)
      assert_equal 1.1, config.version
      assert_nil config.baseline_path
    end
  end
end
