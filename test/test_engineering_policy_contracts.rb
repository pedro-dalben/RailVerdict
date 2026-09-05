# frozen_string_literal: true

require_relative "test_helper"

# Contract tests for configuration 1.7 and engineering-policy-v1 (1.7, ADR 0020):
# version dispatch, closed schemas, bounds, duplicate keys, round-trips, and
# proof that v1 contracts were not silently altered.
class TestEngineeringPolicyContracts < Minitest::Test
  def validate_config(data)
    RailVerdict::SchemaValidator.validate_configuration(data)
  end

  def minimal_analyzers
    { "rubocop" => { "enabled" => true, "required" => false } }
  end

  def test_valid_17_config_with_full_policy
    data = { "version" => 1.7, "mode" => "no_new_debt", "analyzers" => minimal_analyzers,
      "engineering_policy" => {
        "findings" => { "new_critical" => "forbid", "new_high" => "forbid" },
        "coverage" => { "changed_lines_minimum" => 85 },
        "changes" => { "authorization" => { "require_analyzers" => %w[rspec brakeman], "verification_scope" => "full" },
                        "migration" => { "verification_scope" => "full" } },
        "review" => { "high" => { "human_review" => "required" } }
      } }
    assert_empty validate_config(data)
  end

  def test_17_config_without_policy_section_is_valid
    assert_empty validate_config("version" => 1.7, "mode" => "advisory", "analyzers" => minimal_analyzers)
  end

  def test_16_config_rejects_engineering_policy_section
    data = { "version" => 1.6, "mode" => "advisory", "analyzers" => minimal_analyzers,
      "engineering_policy" => { "findings" => { "new_high" => "forbid" } } }
    refute_empty validate_config(data)
  end

  def test_old_configs_still_validate
    assert_empty validate_config("version" => 1, "mode" => "strict", "analyzers" => minimal_analyzers)
    assert_empty validate_config("version" => 1.5, "mode" => "no_new_debt", "analyzers" => minimal_analyzers)
    assert_empty validate_config("version" => 1.6, "mode" => "no_new_debt", "analyzers" => minimal_analyzers,
      "review" => { "risk" => { "migration" => "high" } })
  end

  def test_unknown_policy_fields_rejected
    data = { "version" => 1.7, "mode" => "advisory", "analyzers" => minimal_analyzers,
      "engineering_policy" => { "teleport" => {} } }
    refute_empty validate_config(data)

    data = { "version" => 1.7, "mode" => "advisory", "analyzers" => minimal_analyzers,
      "engineering_policy" => { "findings" => { "new_medium" => "forbid" } } }
    refute_empty validate_config(data)

    data = { "version" => 1.7, "mode" => "advisory", "analyzers" => minimal_analyzers,
      "engineering_policy" => { "changes" => { "authorization" => { "require_analyzers" => ["teleport"] } } } }
    refute_empty validate_config(data)
  end

  def test_policy_bounds_rejected
    data = { "version" => 1.7, "mode" => "advisory", "analyzers" => minimal_analyzers,
      "engineering_policy" => { "coverage" => { "changed_lines_minimum" => 0 } } }
    refute_empty validate_config(data)

    data = { "version" => 1.7, "mode" => "advisory", "analyzers" => minimal_analyzers,
      "engineering_policy" => { "coverage" => { "changed_lines_minimum" => 101 } } }
    refute_empty validate_config(data)

    long_names = (1..33).to_h { |index| ["area#{index}", { "human_review" => "required" }] }
    data = { "version" => 1.7, "mode" => "advisory", "analyzers" => minimal_analyzers,
      "engineering_policy" => { "review" => long_names } }
    refute_empty validate_config(data)
  end

  def test_duplicate_keys_rejected
    assert_raises(RailVerdict::ConfigurationError) do
      RailVerdict::Configuration.load_strict_yaml("version: 1.7\nversion: 1.7\n", "/tmp/dup.yml")
    end
  end

  def test_envelope_schema_accepts_valid_rejects_malformed
    envelope = {
      "schema_version" => "1.0", "decision" => "REVIEW_REQUIRED", "gate" => "PASS",
      "completion_status" => "complete", "configuration_digest" => "a" * 64, "policy_digest" => "b" * 64,
      "requirements" => [{
        "id" => "req-human-review-high", "kind" => "human_review", "trigger" => "t",
        "status" => "review_required", "required_evidence" => ["e"], "observed_evidence" => [],
        "reason_codes" => ["human_review_required"], "provenance" => "p", "classification" => "review"
      }],
      "reason_codes" => ["engineering_policy_review_required"]
    }
    assert_empty RailVerdict::SchemaValidator.validate_engineering_policy(envelope)

    bad_status = envelope.merge("decision" => "MAYBE")
    refute_empty RailVerdict::SchemaValidator.validate_engineering_policy(bad_status)

    missing = envelope.reject { |key, _| key == "policy_digest" }
    refute_empty RailVerdict::SchemaValidator.validate_engineering_policy(missing)

    extra = envelope.merge("verdict" => "PASS")
    refute_empty RailVerdict::SchemaValidator.validate_engineering_policy(extra)

    oversized = envelope.merge("requirements" => Array.new(129) { envelope["requirements"].first })
    refute_empty RailVerdict::SchemaValidator.validate_engineering_policy(oversized)
  end

  def test_canonical_json_orders_and_round_trips
    envelope = {
      "reason_codes" => ["b", "a"], "requirements" => [],
      "schema_version" => "1.0", "decision" => "PASS", "gate" => "PASS",
      "completion_status" => "complete", "configuration_digest" => "a" * 64, "policy_digest" => "b" * 64
    }
    first = RailVerdict::CanonicalJSON.generate(envelope)
    second = RailVerdict::CanonicalJSON.generate(JSON.parse(first))
    assert_equal first, second
    assert(first.index('"completion_status"') < first.index('"decision"'))
    assert_empty RailVerdict::SchemaValidator.validate_engineering_policy(JSON.parse(first))
  end

  def test_result_v1_schema_untouched_by_policy
    gate = {
      "schema_version" => "1.0", "completion_status" => "complete", "gate" => "PASS",
      "policy_status" => "pass", "findings" => [], "analyzer_results" => [],
      "operational_failures" => [], "decision_reasons" => [{ "code" => "x", "message" => "y" }]
    }
    assert_empty RailVerdict::SchemaValidator.validate_result(gate)
    refute_includes gate.keys, "decision"
    refute_includes gate.keys, "requirements"
  end
end
