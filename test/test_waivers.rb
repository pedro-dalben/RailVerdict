# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "fileutils"

class TestWaivers < Minitest::Test
  def finding(path: "app/a.rb", message: "msg", rule_id: "Style/Foo")
    fingerprint = RailVerdict::Finding.fingerprint_for(analyzer: "rubocop", rule_id: rule_id, path: path, message: message)
    RailVerdict::Finding.new(
      fingerprint: fingerprint,
      origin: "deterministic",
      analyzer: "rubocop",
      rule_id: rule_id,
      category: "style",
      severity: "low",
      confidence: "high",
      state: "observed",
      evidence_ref: "native:rubocop:#{fingerprint.delete_prefix('sha256:')[0, 12]}",
      location: { "path" => path, "start_line" => 1, "end_line" => 1 },
      message: message
    )
  end

  def waiver_hash(fingerprint, created_at: "2026-08-17T12:00:00Z", expires_at: "2026-08-17T13:00:00Z")
    {
      "fingerprint" => fingerprint,
      "reason" => "accepted",
      "owner" => "team",
      "created_at" => created_at,
      "expires_at" => expires_at
    }
  end

  def test_active_exact_waiver_suppresses_finding
    item = finding(path: "app/a.rb", message: "one")
    hash = waiver_hash(item.fingerprint)
    assert RailVerdict::Waiver.active?(hash, clock: Time.utc(2026, 8, 17, 12, 30, 0))
    refute RailVerdict::Waiver.active?(hash, clock: Time.utc(2026, 8, 17, 13, 30, 0))
  end

  def test_waiver_schema_rejects_wildcard
    hash = {
      "fingerprint" => "Style/*",
      "reason" => "bad",
      "owner" => "me",
      "created_at" => "2026-08-17T12:00:00Z",
      "expires_at" => "2026-08-17T13:00:00Z"
    }
    assert RailVerdict::SchemaValidator.validate_waiver(hash).any?
  end

  def test_waiver_requires_reason_and_owner
    item = finding
    hash = { "fingerprint" => item.fingerprint, "reason" => "", "owner" => "", "created_at" => "2026-08-17T12:00:00Z", "expires_at" => "2026-08-17T13:00:00Z" }
    assert RailVerdict::SchemaValidator.validate_waiver(hash).any?
  end

  def test_waiver_expires_at_must_be_after_created_at
    item = finding
    hash = waiver_hash(item.fingerprint, created_at: "2026-08-17T13:00:00Z", expires_at: "2026-08-17T12:00:00Z")
    assert_raises(RailVerdict::Waiver::IncompatibleError) { RailVerdict::Waiver.validate_hash(hash) }
  end

  def test_waiver_must_be_utc
    item = finding
    hash = waiver_hash(item.fingerprint, created_at: "2026-08-17T12:00:00+00:00", expires_at: "2026-08-17T13:00:00+00:00")
    assert_raises(RailVerdict::Waiver::IncompatibleError) { RailVerdict::Waiver.validate_hash(hash) }
  end

  def test_comparison_applies_active_waiver
    item = finding(path: "app/a.rb", message: "one")
    waiver = waiver_hash(item.fingerprint)
    result = RailVerdict::Comparison.classify(findings: [item], baseline: nil, waivers: [waiver], clock: Time.utc(2026, 8, 17, 12, 30, 0))
    assert_equal 1, result.counts.fetch("waived")
    assert_equal "waived", result.classified_findings.first.state
  end

  def test_expired_waiver_no_longer_suppresses
    item = finding(path: "app/a.rb", message: "one")
    waiver = waiver_hash(item.fingerprint)
    result = RailVerdict::Comparison.classify(findings: [item], baseline: nil, waivers: [waiver], clock: Time.utc(2026, 8, 17, 14, 0, 0))
    assert_equal 0, result.counts.fetch("waived")
    assert_equal 1, result.counts.fetch("introduced")
  end

  def test_orphaned_waiver_is_observable
    item = finding(path: "app/a.rb", message: "one")
    other_fp = RailVerdict::Finding.fingerprint_for(analyzer: "rubocop", rule_id: "Style/Other", path: "app/z.rb", message: "orphan")
    waiver = waiver_hash(other_fp)
    result = RailVerdict::Comparison.classify(findings: [item], baseline: nil, waivers: [waiver], clock: Time.utc(2026, 8, 17, 12, 30, 0))
    assert_equal 1, result.orphaned_waivers.length
    assert_equal other_fp, result.orphaned_waivers.first["fingerprint"]
  end

  def test_malformed_waiver_file_fails_closed
    with_tmpdir do |dir|
      path = File.join(dir, ".railverdict-waivers.json")
      File.write(path, "{ bad json")
      assert_raises(RailVerdict::Waiver::IncompatibleError) { RailVerdict::WaiverStore.read(path) }
    end
  end

  def test_waiver_store_rejects_duplicate_fingerprint
    with_tmpdir do |dir|
      item = finding(path: "app/a.rb", message: "one")
      hash = waiver_hash(item.fingerprint)
      path = File.join(dir, ".railverdict-waivers.json")
      File.write(path, JSON.generate({ "schema_version" => "1.0", "waivers" => [hash, hash] }))
      assert_raises(RailVerdict::Waiver::IncompatibleError) { RailVerdict::WaiverStore.read(path) }
    end
  end

  def test_check_does_not_mutate_waiver_file
    with_tmpdir do |dir|
      project = File.join(dir, "project")
      FileUtils.cp_r(File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "test/fixtures/rails_clean"), project)
      item = finding
      waiver = waiver_hash(item.fingerprint)
      waiver_path = File.join(project, ".railverdict-waivers.json")
      File.write(waiver_path, JSON.generate({ "schema_version" => "1.0", "waivers" => [waiver] }))
      mtime_before = File.mtime(waiver_path)
      content_before = File.read(waiver_path)
      RailVerdict::Check.execute(repository_root: project, config_path: ".railverdict.yml", waiver_path_override: waiver_path, clock: Time.utc(2026, 8, 17, 12, 30, 0))
      assert_equal content_before, File.read(waiver_path)
      assert_equal mtime_before, File.mtime(waiver_path)
    end
  end
end
