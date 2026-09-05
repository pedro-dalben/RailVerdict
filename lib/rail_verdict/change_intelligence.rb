# frozen_string_literal: true

require_relative "change_surfaces"

module RailVerdict
  # Deterministic change intelligence assembly.
  #
  # Read-only projection over an executed verification Outcome plus its
  # detected surfaces. NEVER influences GateResult: every method here is a
  # pure function of already-decided verification evidence.
  #
  # Confidence vocabulary: surfaces carry their own detection tier
  # ("detected" / "inferred" / "mixed"); anything that cannot be established
  # deterministically is reported under missing_evidence as "unknown" — never
  # as a fact.
  module ChangeIntelligence
    RISK_ORDER = { "low" => 0, "medium" => 1, "high" => 2, "critical" => 3 }.freeze

    SIGNAL_CODES = {
      "security" => "security_config_changed",
      "authorization" => "authorization_surface_changed",
      "authentication" => "authentication_surface_changed",
      "migration" => "migration_added",
      "database" => "database_surface_changed",
      "dependencies" => "dependency_changed",
      "public_api" => "public_api_changed",
      "routes" => "routes_changed",
      "shared_infrastructure" => "shared_infrastructure_changed",
      "configuration" => "configuration_changed"
    }.freeze

    # Priority order for Review Focus (trust-critical first).
    FOCUS_ORDER = %w[
      security authorization authentication migration database dependencies
      public_api routes shared_infrastructure configuration controllers models
      background_jobs mailers views storage initializers test_infrastructure
    ].freeze

    module_function

    def changed_paths(git_context)
      return nil unless git_context

      git_context.changed_files.flat_map { |file| [file.path, file.old_path, file.new_path] }.compact.uniq.sort
    end

    # Array of { code, surface?, project_area?, detail, paths, sensitive }.
    def review_signals(surfaces, project_areas)
      signals = []
      SIGNAL_CODES.each do |surface_id, code|
        entry = surfaces[surface_id]
        next unless entry && entry["available"] && entry["changed"]

        signals << {
          "code" => code,
          "surface" => surface_id,
          "detail" => "#{ChangeSurfaces::SURFACES[surface_id]['label']} surface changed",
          "paths" => entry["evidence"],
          "additional_evidence_count" => entry["additional_evidence_count"],
          "sensitive" => entry["sensitive"],
          "detection" => entry["detection"]
        }
      end
      Array(project_areas).each do |area|
        next unless area["available"] && area["changed"]

        signals << {
          "code" => "project_sensitive_path_changed:#{area['name']}",
          "project_area" => area["name"],
          "detail" => "Project-defined sensitive area '#{area['name']}' changed",
          "paths" => area["evidence"],
          "additional_evidence_count" => area["additional_evidence_count"],
          "sensitive" => true,
          "detection" => "detected"
        }
      end
      signals
    end

    # { level, reasons, configured } — max-severity aggregation, explainable.
    def review_risk(signals, risk_overrides)
      overrides = risk_overrides.is_a?(Hash) ? risk_overrides : {}
      reasons = []
      level = "low"
      signals.each do |signal|
        base = if signal["project_area"]
          "high"
        else
          ChangeSurfaces::SURFACES.dig(signal["surface"], "default_risk")
        end
        next if base.nil?

        mapped = overrides.fetch(signal["surface"] || signal["code"], base).to_s
        mapped = base unless RISK_ORDER.key?(mapped)
        reasons << signal["code"]
        level = mapped if RISK_ORDER[mapped] > RISK_ORDER[level]
      end
      { "level" => level.upcase, "reasons" => reasons.uniq.sort,
        "configured" => !overrides.empty? }
    end

    # { available, reason?, frameworks: { rspec|minitest => {...} } }.
    # Executed analyzer evidence wins; when an analyzer did not execute,
    # the deterministic TestSelection recompute is reported as the selection
    # basis with executed: false.
    def verification_scope(result, repository_root:, git_context:)
      frameworks = {}
      %w[rspec minitest].each do |name|
        frameworks[name] = framework_scope(result, name,
          repository_root: repository_root, git_context: git_context)
      end
      if frameworks.values.all? { |entry| entry["scope"] == "unknown" }
        { "available" => false, "reason" => "test_scope_unavailable", "frameworks" => frameworks }
      else
        { "available" => true, "frameworks" => frameworks }
      end
    end

    def framework_scope(result, name, repository_root:, git_context:)
      analyzer = result.analyzer_results.find { |item| item.analyzer == name }
      summary = analyzer&.evidence_summary
      if analyzer && analyzer.execution_status == "succeeded" && summary.is_a?(Hash)
        entry = {
          "available" => true, "executed" => true,
          "execution_status" => analyzer.execution_status,
          "scope" => summary["test_scope"] || "full"
        }
        entry["selected_files"] = Array(summary["target_files"]).compact.sort if summary["target_files"]
        entry["fallback_reason"] = summary["fallback_reason"] if summary["fallback_reason"]
        return entry
      end
      return { "available" => false, "executed" => false, "scope" => "unknown",
               "reason" => analyzer ? "analyzer_#{analyzer.execution_status}" : "analyzer_not_configured" } unless git_context

      begin
        selection = TestSelection.resolve(repository_root: repository_root,
          git_context: git_context, framework: name.to_sym)
        entry = { "available" => true, "executed" => false,
                  "execution_status" => analyzer ? analyzer.execution_status : "not_executed",
                  "scope" => selection.scope }
        entry["selected_files"] = selection.selected_files if selection.scope == "targeted"
        entry["fallback_reason"] = selection.fallback_reason if selection.fallback_reason
        entry
      rescue StandardError
        { "available" => false, "executed" => false, "scope" => "unknown",
          "reason" => "selection_unresolvable" }
      end
    end
    private_class_method :framework_scope

    # Array of { code, detail, reason }. Facts about gaps, never guesses.
    def missing_evidence(outcome, surfaces, verification_scope)
      result = outcome.result
      gaps = []
      auth = surfaces["authorization"]
      if auth && auth["available"] && auth["changed"]
        gaps << {
          "code" => "authorization_changed_verification_not_established",
          "detail" => "Authorization surface changed; no deterministic authorization-to-test mapping exists",
          "reason" => "no_deterministic_relationship_established",
          "confidence" => "unknown"
        }
      end
      verification_scope.fetch("frameworks", {}).each do |name, entry|
        reason = entry["fallback_reason"].to_s
        next unless reason.start_with?("unmapped_source_change:", "unrecognized_source_file:")

        outcome_text = entry["executed"] ? "full suite ran instead" : "full suite required (#{name} not executed)"
        gaps << {
          "code" => "targeted_test_mapping_ambiguous",
          "detail" => "#{name}: #{reason} — #{outcome_text}",
          "reason" => reason,
          "confidence" => "unknown"
        }
      end
      configuration = outcome.respond_to?(:configuration) ? outcome.configuration : nil
      configuration = nil unless configuration.respond_to?(:analyzer_required?)
      if configuration
        required_incomplete = result.analyzer_results.select do |analyzer|
          begin
            configuration.analyzer_required?(analyzer.analyzer)
          rescue StandardError
            false
          end && analyzer.execution_status != "succeeded"
        end
        required_incomplete.each do |analyzer|
          gaps << {
            "code" => "required_analyzer_incomplete",
            "detail" => "Required analyzer '#{analyzer.analyzer}' did not succeed (#{analyzer.execution_status})",
            "reason" => analyzer.failure ? analyzer.failure["code"].to_s : analyzer.execution_status,
            "confidence" => "detected"
          }
        end
      end
      coverage = result.analyzer_results.find { |item| item.analyzer == "simplecov" }
      if coverage.nil? || coverage.execution_status != "succeeded"
        gaps << {
          "code" => "coverage_evidence_unavailable",
          "detail" => "Changed-lines coverage could not be established",
          "reason" => coverage ? "simplecov_#{coverage.execution_status}" : "simplecov_not_configured",
          "confidence" => "unknown"
        }
      end
      unless result.baseline && result.baseline["loaded"] == true
        gaps << {
          "code" => "baseline_unavailable",
          "detail" => "No quality delta: baseline not loaded, so introduced/resolved cannot be distinguished from existing",
          "reason" => result.baseline && result.baseline["compatible"] == false ? "baseline_incompatible" : "baseline_not_available",
          "confidence" => "detected"
        }
      end
      gaps << {
        "code" => "git_scope_unavailable",
        "detail" => "Changed scope could not be established; surfaces, signals, and focus are unavailable",
        "reason" => "git_scope_unavailable",
        "confidence" => "detected"
      } if outcome.context&.git_context.nil? && result.git.nil?
      gaps
    end
    # Ordered { rank, surface, title, reason, paths, additional_evidence_count }.
    # Non-sensitive items whose evidence is fully covered by higher-ranked
    # items are skipped to reduce the review search space; sensitive items
    # and project areas are always shown. Deterministic: FOCUS_ORDER decides.
    def review_focus(surfaces, project_areas)
      items = []
      covered = {}
      FOCUS_ORDER.each do |surface_id|
        entry = surfaces[surface_id]
        next unless entry && entry["available"] && entry["changed"]

        sensitive = ChangeSurfaces::SURFACES[surface_id]["default_risk"] != nil
        paths = entry["evidence"].first(10)
        unless sensitive
          next if !paths.empty? && paths.all? { |path| covered.key?(path) }
        end
        paths.each { |path| covered[path] = true }
        items << {
          "surface" => surface_id,
          "title" => ChangeSurfaces::SURFACES[surface_id]["label"],
          "reason" => "#{ChangeSurfaces::SURFACES[surface_id]['label']} surface changed",
          "paths" => paths,
          "additional_evidence_count" => entry["additional_evidence_count"] + [entry["evidence"].length - 10, 0].max,
          "detection" => entry["detection"]
        }
      end
      Array(project_areas).each do |area|
        next unless area["available"] && area["changed"]

        items << {
          "surface" => "project:#{area['name']}",
          "title" => "Sensitive area: #{area['name']}",
          "reason" => "Project-defined sensitive area '#{area['name']}' changed",
          "paths" => Array(area["evidence"]).first(10),
          "additional_evidence_count" => area["additional_evidence_count"],
          "detection" => "detected"
        }
      end
      items.each_with_index.map { |item, index| item.merge("rank" => index + 1) }
    end
  end
end
