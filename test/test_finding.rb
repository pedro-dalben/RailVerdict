# frozen_string_literal: true

require "json"

require_relative "test_helper"

class TestFinding < Minitest::Test
  def build_finding(path: "app/models/user.rb", start_line: 4, end_line: 4, message: "Prefer double quotes")
    fingerprint = RailVerdict::Finding.fingerprint_for(
      analyzer: "rubocop",
      rule_id: "Style/StringLiterals",
      path: path,
      message: message
    )
    RailVerdict::Finding.new(
      fingerprint: fingerprint,
      origin: "deterministic",
      analyzer: "rubocop",
      rule_id: "Style/StringLiterals",
      category: "style",
      severity: "low",
      confidence: "high",
      state: "observed",
      evidence_ref: "native:rubocop:#{fingerprint.delete_prefix("sha256:")[0, 12]}",
      location: { "path" => path, "start_line" => start_line, "end_line" => end_line },
      message: message
    )
  end

  def test_finding_matches_versioned_schema
    finding = build_finding
    assert_empty RailVerdict::SchemaValidator.validate_finding(finding.to_schema_h)
    assert_equal "1.0", finding.schema_version
    assert_equal "observed", finding.state
    assert finding.frozen?
    assert finding.location.frozen?
  end

  def test_fingerprint_is_stable_and_excludes_line_numbers
    first = build_finding(start_line: 4).fingerprint
    second = RailVerdict::Finding.fingerprint_for(
      message: "Prefer double quotes", path: "app/models/user.rb",
      rule_id: "Style/StringLiterals", analyzer: "rubocop"
    )
    assert_equal first, second
    assert_equal first, build_finding(start_line: 99, end_line: 100).fingerprint
    refute_equal first, RailVerdict::Finding.fingerprint_for(
      analyzer: "rubocop", rule_id: "Style/Foo", path: "app/a.rb", message: "Other"
    )
  end

  def test_id_is_deterministic_from_fingerprint
    first = build_finding
    second = build_finding
    assert_equal first.id, second.id
    assert_match(/\Arv:[0-9a-f]{20}\z/, first.id)
  end

  def test_location_ordering_and_missing_lines
    without_lines = build_finding(start_line: nil, end_line: nil)
    with_lines = build_finding(start_line: 1, end_line: 1)
    assert_equal(-1, without_lines.sort_key <=> with_lines.sort_key)
  end

  def test_invalid_fingerprint_is_rejected
    assert_raises(ArgumentError) do
      RailVerdict::Finding.new(
        fingerprint: "sha256:bad",
        origin: "deterministic",
        analyzer: "rubocop",
        rule_id: "Style/Foo",
        category: "style",
        severity: "low",
        confidence: "high",
        state: "observed",
        evidence_ref: "native",
        location: { "path" => "app/a.rb" },
        message: "message"
      )
    end
  end

  def test_invalid_locations_are_rejected
    ["/absolute.rb", "../escape.rb", "app/../escape.rb", "app\\bad.rb", "app//bad.rb", "app\u0000bad.rb"].each do |path|
      assert_raises(ArgumentError, path) { build_finding(path: path) }
    end
    assert_raises(ArgumentError) { build_finding(start_line: 10, end_line: 9) }
  end

  def test_invalid_enum_and_message_values_are_rejected
    finding = build_finding
    invalid = finding.to_schema_h.merge("severity" => "blocker")
    assert RailVerdict::SchemaValidator.validate_finding(invalid).any?
    assert_raises(ArgumentError) { build_finding(message: "") }
    assert_raises(ArgumentError) { build_finding(message: "x" * 4097) }
  end

  def test_finding_has_no_policy_authority_fields
    refute_includes build_finding.to_schema_h.keys, "blocking"
    refute_includes build_finding.to_schema_h.keys, "gate"
    refute_respond_to build_finding, :blocking
  end
end
