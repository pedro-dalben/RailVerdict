# frozen_string_literal: true

require_relative "test_helper"

class TestChangeIntelligence < Minitest::Test
  PATHS = [
    "app/policies/account_policy.rb",
    "app/controllers/accounts_controller.rb",
    "db/migrate/20260801000000_add_account_constraint.rb",
    "db/schema.rb",
    "Gemfile.lock",
    "config/routes.rb",
    "app/models/account.rb"
  ].freeze

  def surfaces(paths = PATHS)
    RailVerdict::ChangeSurfaces.detect(paths, available: true)
  end

  def test_detects_core_surfaces_with_evidence
    detected = surfaces
    assert_equal true, detected["authorization"]["changed"]
    assert_equal ["app/policies/account_policy.rb"], detected["authorization"]["evidence"]
    assert_equal "detected", detected["authorization"]["detection"]
    assert_equal true, detected["migration"]["changed"]
    assert_equal true, detected["dependencies"]["changed"]
    assert_equal true, detected["routes"]["changed"]
    assert_equal true, detected["database"]["changed"]
    assert_equal true, detected["controllers"]["changed"]
    assert_equal false, detected["background_jobs"]["changed"]
    assert_equal false, detected["mailers"]["changed"]
  end

  def test_never_asserts_without_evidence
    detected = surfaces([])
    detected.each_value do |entry|
      assert_equal false, entry["changed"]
      assert_empty entry["evidence"]
    end
  end

  def test_git_unavailable_fails_closed
    detected = RailVerdict::ChangeSurfaces.detect(nil, available: false)
    detected.each_value do |entry|
      assert_equal false, entry["available"]
      assert_equal "git_scope_unavailable", entry["reason"]
    end
  end

  def test_authentication_and_public_api_are_inferred
    detected = surfaces(["app/controllers/sessions_controller.rb", "app/controllers/api/orders_controller.rb"])
    assert_equal true, detected["authentication"]["changed"]
    assert_equal "inferred", detected["authentication"]["detection"]
    assert_equal true, detected["public_api"]["changed"]
    assert_equal "inferred", detected["public_api"]["detection"]
  end

  def test_project_sensitive_globs_match
    areas = RailVerdict::ChangeSurfaces.project_sensitive(
      PATHS + ["app/services/billing/charge.rb"],
      { "financial" => ["app/services/billing/**", "app/models/payment.rb"] },
      available: true
    )
    financial = areas.find { |area| area["name"] == "financial" }
    assert_equal true, financial["changed"]
    assert_equal ["app/services/billing/charge.rb"], financial["evidence"]
  end

  def test_risk_is_explainable_and_max_aggregated
    signals = RailVerdict::ChangeIntelligence.review_signals(surfaces, [])
    risk = RailVerdict::ChangeIntelligence.review_risk(signals, {})
    assert_equal "HIGH", risk["level"]
    assert_includes risk["reasons"], "authorization_surface_changed"
    assert_includes risk["reasons"], "migration_added"
    assert_includes risk["reasons"], "dependency_changed"
    assert_equal false, risk["configured"]
  end

  def test_security_drives_critical
    detected = surfaces(["config/credentials.yml.enc"])
    signals = RailVerdict::ChangeIntelligence.review_signals(detected, [])
    risk = RailVerdict::ChangeIntelligence.review_risk(signals, {})
    assert_equal "CRITICAL", risk["level"]
  end

  def test_quiet_change_is_low
    detected = surfaces(["app/views/home/index.html.erb"])
    signals = RailVerdict::ChangeIntelligence.review_signals(detected, [])
    risk = RailVerdict::ChangeIntelligence.review_risk(signals, {})
    assert_equal "LOW", risk["level"]
    assert_empty risk["reasons"]
  end

  def test_project_risk_override_is_honored
    detected = surfaces(["Gemfile.lock"])
    signals = RailVerdict::ChangeIntelligence.review_signals(detected, [])
    risk = RailVerdict::ChangeIntelligence.review_risk(signals, { "dependencies" => "critical" })
    assert_equal "CRITICAL", risk["level"]
    assert_equal true, risk["configured"]
  end

  def test_focus_skips_fully_covered_non_sensitive_surface
    detected = surfaces(["app/models/account.rb", "db/schema.rb"])
    focus = RailVerdict::ChangeIntelligence.review_focus(detected, [])
    surfaces_in_focus = focus.map { |item| item["surface"] }
    assert_includes surfaces_in_focus, "database"
    refute_includes surfaces_in_focus, "models"
    assert_equal (1..focus.length).to_a, focus.map { |item| item["rank"] }
  end

  def test_focus_appends_unmapped_pointer_for_unknown_paths
    detected = surfaces(["lib/pricing.rb"])
    focus = RailVerdict::ChangeIntelligence.review_focus(detected, [], ["lib/pricing.rb"])
    unmapped = focus.find { |item| item["surface"] == "unmapped" }
    refute_nil unmapped
    assert_equal ["lib/pricing.rb"], unmapped["paths"]
    assert_equal 0, unmapped["additional_evidence_count"]
    assert_equal focus.length, unmapped["rank"]
    assert_equal (1..focus.length).to_a, focus.map { |item| item["rank"] }
  end

  def test_focus_omits_unmapped_pointer_when_everything_mapped
    detected = surfaces(["app/policies/account_policy.rb"])
    focus = RailVerdict::ChangeIntelligence.review_focus(detected, [], ["app/policies/account_policy.rb"])
    assert_nil focus.find { |item| item["surface"] == "unmapped" }
  end

  def test_review_focus_is_ordered_with_reasons
    focus = RailVerdict::ChangeIntelligence.review_focus(surfaces, [])
    assert_equal (1..focus.length).to_a, focus.map { |item| item["rank"] }
    assert_equal "authorization", focus.first["surface"]
    focus.each do |item|
      refute_empty item["reason"]
      refute_empty item["paths"]
    end
  end

  def test_focus_keeps_sensitive_surface_despite_overlap
    detected = surfaces(["app/policies/account_policy.rb", "app/controllers/accounts_controller.rb"])
    focus = RailVerdict::ChangeIntelligence.review_focus(detected, [])
    assert_includes focus.map { |item| item["surface"] }, "authorization"
    assert_includes focus.map { |item| item["surface"] }, "controllers"
  end

  def test_ambiguous_mapping_wording_marks_unexecuted_analyzer
    outcome = Struct.new(:result, :context, :configuration).new(fake_result([]), nil, nil)
    scope = {
      "available" => true, "frameworks" => {
        "rspec" => { "scope" => "full", "executed" => false,
                     "fallback_reason" => "unmapped_source_change:app/models/x.rb" }
      }
    }
    gaps = RailVerdict::ChangeIntelligence.missing_evidence(outcome, surfaces([]), scope)
    gap = gaps.find { |item| item["code"] == "targeted_test_mapping_ambiguous" }
    assert_includes gap["detail"], "not executed"
  end

  def test_focus_includes_project_areas
    areas = RailVerdict::ChangeSurfaces.project_sensitive(
      ["app/services/billing/charge.rb"], { "financial" => ["app/services/billing/**"] }, available: true
    )
    focus = RailVerdict::ChangeIntelligence.review_focus(surfaces([]), areas)
    assert_equal 1, focus.length
    assert_equal "project:financial", focus.first["surface"]
  end

  def test_verification_scope_reads_executed_evidence
    summary = { "test_scope" => "targeted", "target_files" => ["spec/models/a_spec.rb"] }
    analyzer = RailVerdict::AnalyzerResult.new(
      analyzer: "rspec",
      invocation: { "executable" => "rspec", "argv" => [] },
      execution_status: "succeeded",
      finding_ids: [],
      evidence_summary: summary.merge("tests_total" => 1, "failures" => 0)
    )
    result = fake_result([analyzer])
    scope = RailVerdict::ChangeIntelligence.verification_scope(result, repository_root: nil, git_context: nil)
    assert_equal true, scope["available"]
    rspec = scope["frameworks"]["rspec"]
    assert_equal "targeted", rspec["scope"]
    assert_equal true, rspec["executed"]
    assert_equal ["spec/models/a_spec.rb"], rspec["selected_files"]
  end

  def test_missing_evidence_reports_unknown_honestly
    outcome = Struct.new(:result, :context, :configuration).new(fake_result([]), nil, nil)
    scope = { "available" => false, "reason" => "test_scope_unavailable", "frameworks" => {} }
    gaps = RailVerdict::ChangeIntelligence.missing_evidence(outcome, surfaces, scope)
    codes = gaps.map { |gap| gap["code"] }
    assert_includes codes, "authorization_changed_verification_not_established"
    assert_includes codes, "coverage_evidence_unavailable"
    assert_includes codes, "baseline_unavailable"
    auth_gap = gaps.find { |gap| gap["code"] == "authorization_changed_verification_not_established" }
    assert_equal "unknown", auth_gap["confidence"]
    refute_includes codes, "required_analyzer_incomplete"
  end

  def test_gate_result_untouched_by_intelligence
    gate_before = fake_result([]).gate
    outcome = Struct.new(:result, :context, :configuration).new(fake_result([]), nil, nil)
    RailVerdict::ChangeIntelligence.review_focus(surfaces, [])
    RailVerdict::ChangeIntelligence.missing_evidence(
      outcome, surfaces,
      { "available" => false, "reason" => "x", "frameworks" => {} }
    )
    assert_equal gate_before, outcome.result.gate
  end

  private

  def fake_result(analyzers)
    RailVerdict::GateResult.new(
      completion_status: "complete",
      gate: "PASS",
      policy_status: "pass",
      findings: [],
      analyzer_results: analyzers,
      operational_failures: [],
      decision_reasons: [{ "code" => "policy_pass", "message" => "ok" }]
    )
  end
end
