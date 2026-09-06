# frozen_string_literal: true

module RailVerdict
  module Repair
    module VerificationPlan
      def self.build(outcome:, repository_root: nil, base_revision: nil)
        required = [required_check(base_revision: base_revision)]
        suggested = suggested_commands(outcome)
        plan = { "required" => required, "suggested" => suggested }
        observed = observed_execution(outcome)
        plan["execution"] = observed[:execution] unless observed[:execution].nil?
        plan["requirements"] = observed[:requirements] unless observed[:requirements].nil?
        plan["reasons"] = observed[:reasons] unless observed[:reasons].nil?
        plan
      end

      # Observed facts about the verification that produced this packet: which
      # analyzers executed, per-framework test scope, and policy requirement
      # statuses. Never a prediction; re-running `required` re-plans via the
      # canonical engine. Best-effort: absent on outcomes that cannot project.
      def self.observed_execution(outcome)
        document = PRIntelligence.document(outcome)
        policy = EngineeringPolicy.evaluate(outcome: outcome, pr_document: document)
        scope = document["verification_scope"].is_a?(Hash) ? document["verification_scope"] : {}
        frameworks = scope["frameworks"].is_a?(Hash) ? scope["frameworks"] : {}
        evidence = Array(document["analyzer_evidence"])
        {
          execution: {
            "analyzers_executed" => evidence.select { |entry| entry["evidence_status"] == "complete" }
              .map { |entry| entry["analyzer"].to_s }.sort,
            "test_scope" => frameworks.to_h do |name, entry|
              [name.to_s, { "executed" => entry["executed"] == true, "scope" => entry["scope"].to_s }]
            end
          },
          requirements: Array(policy["requirements"]).map do |entry|
            { "id" => entry["id"], "status" => entry["status"] }
          end.sort_by { |entry| entry["id"] },
          reasons: Array(policy["reason_codes"]).sort
        }
      rescue RailVerdict::Error, ArgumentError, NoMethodError
        {}
      end

      def self.required_check(base_revision: nil)
        argv = ["exec", "railverdict", "check"]
        if base_revision && !base_revision.strip.empty?
          argv += ["--changed", "--base", base_revision.strip]
        end
        {
          "executable" => "bundle",
          "argv" => argv,
          "display" => "bundle #{argv.join(' ')}"
        }
      end

      def self.suggested_commands(outcome)
        findings = outcome.findings || []
        analyzers = findings.map(&:analyzer).uniq.sort
        analyzers.first(3).map do |analyzer|
          case analyzer
          when "rubocop"
            { "executable" => "bundle", "argv" => ["exec", "rubocop"], "display" => "bundle exec rubocop" }
          when "minitest"
            { "executable" => "bundle", "argv" => ["exec", "rake", "test"], "display" => "bundle exec rake test" }
          when "rspec"
            { "executable" => "bundle", "argv" => ["exec", "rspec"], "display" => "bundle exec rspec" }
          when "bundler_audit"
            { "executable" => "bundle", "argv" => ["exec", "bundler-audit", "check"], "display" => "bundle exec bundler-audit check" }
          else
            nil
          end
        end.compact
      end
      private_class_method :suggested_commands
    end
  end
end
