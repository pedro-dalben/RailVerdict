# frozen_string_literal: true

require_relative "reuse"
require_relative "test_selection"

module RailVerdict
  class VerificationPlan
    attr_reader :analyzers_to_reuse, :analyzers_to_execute, :decisions,
                :test_scope, :target_files, :fallback_reasons, :reused_results, :reused_findings

    def initialize(analyzers_to_reuse:, analyzers_to_execute:, decisions:, test_scope: "full", target_files: {}, fallback_reasons: {}, reused_results: {}, reused_findings: {})
      @analyzers_to_reuse = analyzers_to_reuse.map(&:to_s).freeze
      @analyzers_to_execute = analyzers_to_execute.map(&:to_s).freeze
      @decisions = decisions.freeze
      @test_scope = test_scope.freeze
      @target_files = target_files.freeze
      @fallback_reasons = fallback_reasons.freeze
      @reused_results = reused_results.freeze
      @reused_findings = reused_findings.freeze
      freeze
    end

    def self.build(repository_root:, configuration:, probes: {}, git_context: nil, handoff_document: nil, current_repository_state: nil, current_environment: nil, changed: false)
      analyzers_to_reuse = []
      analyzers_to_execute = []
      decisions = {}
      target_files = {}
      fallback_reasons = {}
      reused_results = {}
      reused_findings = {}

      overall_test_scope = "full"

      # 2. Evaluate each enabled analyzer
      configuration.analyzers.each do |name, selection|
        next unless selection.fetch("enabled")

        name = name.to_s
        if name == "rspec" && changed && git_context
          rspec_selection = TestSelection.resolve(repository_root: repository_root, git_context: git_context, framework: :rspec)
          if rspec_selection.scope == "targeted" && rspec_selection.selected_files.any?
            target_files[name] = rspec_selection.selected_files
            overall_test_scope = "targeted"
          else
            target_files[name] = nil
            fallback_reasons[name] = rspec_selection.fallback_reason
          end
        elsif name == "minitest" && changed && git_context
          minitest_selection = TestSelection.resolve(repository_root: repository_root, git_context: git_context, framework: :minitest)
          if minitest_selection.scope == "targeted" && minitest_selection.selected_files.any?
            target_files[name] = minitest_selection.selected_files
            overall_test_scope = "targeted"
          else
            target_files[name] = nil
            fallback_reasons[name] = minitest_selection.fallback_reason
          end
        end

        # Check if previous evidence can be reused
        if handoff_document
          eval_res = Reuse.evaluate_analyzer(
            analyzer_id: name,
            handoff_document: handoff_document,
            current_repository_state: current_repository_state,
            current_environment: current_environment,
            configuration: configuration
          )

          if eval_res.decision == Reuse::REUSABLE
            analyzers_to_reuse << name
            decisions[name] = { "action" => "reuse", "reasons" => eval_res.reasons }
            reused_results[name] = eval_res.analyzer_result
            reused_findings[name] = eval_res.findings
            next
          else
            decisions[name] = { "action" => "execute", "reasons" => eval_res.reasons }
          end
        else
          decisions[name] = { "action" => "execute", "reasons" => ["no_previous_evidence"] }
        end

        analyzers_to_execute << name
      end

      new(
        analyzers_to_reuse: analyzers_to_reuse,
        analyzers_to_execute: analyzers_to_execute,
        decisions: decisions,
        test_scope: overall_test_scope,
        target_files: target_files,
        fallback_reasons: fallback_reasons,
        reused_results: reused_results,
        reused_findings: reused_findings
      )
    end
  end
end
