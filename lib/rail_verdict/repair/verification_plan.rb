# frozen_string_literal: true

module RailVerdict
  module Repair
    module VerificationPlan
      def self.build(outcome:, repository_root: nil, base_revision: nil)
        required = [required_check(base_revision: base_revision)]
        suggested = suggested_commands(outcome)
        { "required" => required, "suggested" => suggested }
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
