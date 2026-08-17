# frozen_string_literal: true

module RailVerdict
  module Intelligence
    class Budget
      DEFAULTS = {
        max_findings: 3,
        max_requests: 3,
        max_context_bytes: 64 * 1024
      }.freeze

      attr_reader :max_findings, :max_requests, :max_context_bytes

      def initialize(config_budgets = {})
        @max_findings = (config_budgets["max_findings"] || DEFAULTS[:max_findings]).to_i
        @max_requests = (config_budgets["max_requests"] || DEFAULTS[:max_requests]).to_i
        @max_context_bytes = (config_budgets["max_context_bytes"] || DEFAULTS[:max_context_bytes]).to_i
      end

      def enforce!(manifest)
        if manifest.total_bytes > max_context_bytes
          raise AIFailure.new(code: "budget_exhausted", message: "context exceeds max_context_bytes #{max_context_bytes}")
        end
      end

      def self.select_findings(findings, limit:)
        severity_rank = { "critical" => 0, "high" => 1, "medium" => 2, "low" => 3, "info" => 4 }
        findings.sort_by do |f|
          blocking = f.respond_to?(:state) ? (f.state == "introduced" ? 0 : 1) : 1
          sev = severity_rank[f.severity] || 5
          [blocking, sev, f.sort_key]
        end.first(limit)
      end
    end
  end
end
