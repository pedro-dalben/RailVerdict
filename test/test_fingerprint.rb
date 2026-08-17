# frozen_string_literal: true

require "digest"
require "json"

require_relative "test_helper"

class TestFingerprint < Minitest::Test
  def fp(analyzer: "rubocop", rule_id: "Style/StringLiterals", path: "app/models/user.rb", message: "Prefer double quotes")
    RailVerdict::Fingerprint.hexdigest(analyzer: analyzer, rule_id: rule_id, path: path, message: message)
  end

  def legacy_digest(analyzer: "rubocop", rule_id: "Style/StringLiterals", path: "app/models/user.rb", message: "Prefer double quotes")
    payload = {
      "analyzer" => analyzer.to_s,
      "message" => message.to_s,
      "path" => path.to_s,
      "payload_schema" => RailVerdict::Fingerprint::LEGACY_PAYLOAD_SCHEMA,
      "rule_id" => rule_id.to_s
    }
    canonical = payload.keys.sort.to_h { |key| [key, payload.fetch(key)] }
    "sha256:#{Digest::SHA256.hexdigest(JSON.generate(canonical))}"
  end

  def test_version_and_schema_constants
    assert_equal 1, RailVerdict::Fingerprint::VERSION
    assert_equal "sha256", RailVerdict::Fingerprint::ALGORITHM
    assert_equal "https://railverdict.dev/fingerprint-payload/v1", RailVerdict::Fingerprint::PAYLOAD_SCHEMA
    assert_match(/\Asha256:[0-9a-f]{64}\z/, fp)
  end

  def test_finding_delegates_to_fingerprint
    assert_equal fp, RailVerdict::Finding.fingerprint_for(analyzer: "rubocop", rule_id: "Style/StringLiterals", path: "app/models/user.rb", message: "Prefer double quotes")
    assert_equal RailVerdict::Fingerprint::PAYLOAD_SCHEMA, RailVerdict::Finding::FINGERPRINT_PAYLOAD_SCHEMA
  end

  def test_canonical_payload_excludes_line_numbers
    payload = RailVerdict::Fingerprint.canonical_payload(analyzer: "rubocop", rule_id: "Style/Foo", path: "app/a.rb", message: "msg")
    refute payload.key?("start_line")
    refute payload.key?("end_line")
    assert_equal 1, payload["fingerprint_version"]
    assert_equal "sha256", payload["algorithm"]
  end

  def test_unrelated_lines_inserted_above_do_not_change_fingerprint
    base = fp(path: "app/models/user.rb", message: "Use method")
    assert_equal base, fp(path: "app/models/user.rb", message: "Use method")
  end

  def test_finding_moves_to_another_line_same_fingerprint
    first = RailVerdict::Finding.fingerprint_for(analyzer: "rubocop", rule_id: "Style/Foo", path: "app/a.rb", message: "msg")
    second = RailVerdict::Finding.fingerprint_for(analyzer: "rubocop", rule_id: "Style/Foo", path: "app/a.rb", message: "msg")
    assert_equal first, second
  end

  def test_file_rename_changes_fingerprint
    same_msg = "Prefer double quotes"
    assert_operator fp(path: "app/models/user.rb", message: same_msg), :!=, fp(path: "app/models/order.rb", message: same_msg)
  end

  def test_logical_code_move_same_rule_different_path_is_different
    assert_operator fp(path: "app/models/a.rb", message: "msg"), :!=, fp(path: "app/models/b.rb", message: "msg")
  end

  def test_same_rule_multiple_times_distinct_messages_are_distinct
    assert_operator fp(path: "app/a.rb", rule_id: "Style/StringLiterals", message: "first"), :!=, fp(path: "app/a.rb", rule_id: "Style/StringLiterals", message: "second")
  end

  def test_duplicate_findings_identical_tuple_share_fingerprint
    a = fp(path: "app/a.rb", rule_id: "Style/Foo", message: "dup")
    b = fp(path: "app/a.rb", rule_id: "Style/Foo", message: "dup")
    assert_equal a, b
  end

  def test_copied_code_same_message_different_path_is_different
    assert_operator fp(path: "app/a.rb", message: "same"), :!=, fp(path: "app/b.rb", message: "same")
    assert_equal fp(path: "app/a.rb", message: "same"), fp(path: "app/a.rb", message: "same")
  end

  def test_normalized_path_dot_slash_same
    assert_equal fp(path: "./app/models/user.rb"), fp(path: "app/models/user.rb")
  end

  def test_message_whitespace_normalization
    assert_equal fp(path: "app/a.rb", message: "Prefer double quotes"), fp(path: "app/a.rb", message: "  Prefer   double   quotes  ")
    assert_operator fp(path: "app/a.rb", message: "Prefer double quotes"), :!=, fp(path: "app/a.rb", message: "Prefer single quotes")
  end

  def test_semantic_change_rule_id_changes_fingerprint
    assert_operator fp(rule_id: "Style/StringLiterals"), :!=, fp(rule_id: "Style/Foo")
    assert_operator fp(message: "msg one"), :!=, fp(message: "msg two")
    assert_operator fp(analyzer: "rubocop"), :!=, fp(analyzer: "rspec")
  end

  def test_version_migration_v01_differs_from_v1
    legacy = legacy_digest(path: "app/models/user.rb", message: "Prefer double quotes")
    current = fp(path: "app/models/user.rb", message: "Prefer double quotes")
    refute_equal legacy, current
  end

  def test_canonical_json_key_order_is_sorted
    json = RailVerdict::Fingerprint.canonical_json(analyzer: "rubocop", rule_id: "Style/Foo", path: "app/a.rb", message: "msg")
    keys = JSON.parse(json).keys
    assert_equal keys.sort, keys
  end

  def test_locale_and_timezone_do_not_change_digest
    original_lc = ENV["LC_ALL"]
    original_tz = ENV["TZ"]
    begin
      ENV["LC_ALL"] = "C"
      ENV["TZ"] = "UTC"
      a = fp
      ENV["LC_ALL"] = "C.UTF-8"
      ENV["TZ"] = "America/New_York"
      b = fp
      assert_equal a, b
    ensure
      ENV["LC_ALL"] = original_lc
      ENV["TZ"] = original_tz
    end
  end

  def test_collision_assumption_documented_via_same_payload_shares_digest
    same = fp(path: "app/a.rb", message: "same", rule_id: "Style/Foo", analyzer: "rubocop")
    assert_equal same, fp(path: "app/a.rb", message: "same", rule_id: "Style/Foo", analyzer: "rubocop")
  end
end
