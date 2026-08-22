# frozen_string_literal: true

require "json"

module RailVerdict
  module PRIntelligence
    SCHEMA_VERSION = "1.0"
    MAX_SIGNAL_EVIDENCE = 20
    SIGNALS = {
      "database_change" => lambda { |path| path == "db/schema.rb" || path == "db/structure.sql" || path.start_with?("db/migrate/") },
      "routes_change" => lambda { |path| path == "config/routes.rb" || path.start_with?("config/routes/") },
      "dependency_change" => lambda { |path| %w[Gemfile Gemfile.lock].include?(path) },
      "configuration_change" => lambda { |path| path == "config" || path.start_with?("config/") },
      "authorization_change" => lambda { |path| path.start_with?("app/policies/") },
      "tests_change" => lambda { |path| path.start_with?("spec/") || path.start_with?("test/") }
    }.freeze
    STATUS_KEYS = %w[added modified deleted renamed].freeze
    TEST_KEYS = %w[tests_total assertions failures errors skips duration_seconds seed runner].freeze

    module_function

    def document(outcome)
      result = outcome.result
      git_context = outcome.context&.git_context
      git = result.git || {}

      document = {
        "schema_version" => SCHEMA_VERSION,
        "provenance" => provenance(outcome, git_context, git),
        "gate_result" => result.to_schema_h,
        "change" => change(git_context),
        "signals" => signals(git_context),
        "quality_delta" => quality_delta(result),
        "analyzer_evidence" => analyzer_evidence(result),
        "test_intelligence" => test_intelligence(result),
        "coverage" => coverage(result)
      }
      errors = SchemaValidator.validate_pr_intelligence(document)
      raise RailVerdict::Error, "pr-intelligence-v1 validation failed: #{errors.join('; ')}" unless errors.empty?

      document
    end

    def render_json(outcome)
      JSON.generate(document(outcome)) + "\n"
    end

    def provenance(outcome, git_context, git)
      context = outcome.context
      {
        "repository" => git_context && File.basename(git_context.repository_root),
        "head" => git_context&.head || git["head"],
        "base" => git_context&.base || git["base"],
        "merge_base" => git_context&.merge_base || git["merge_base"],
        "configuration_digest" => context&.configuration_digest
      }
    end
    private_class_method :provenance

    def change(git_context)
      return { "available" => false, "reason" => "git_scope_unavailable" } unless git_context

      files = git_context.changed_files
      lines_added = line_total(files, :lines_added)
      lines_removed = line_total(files, :lines_removed)
      status_counts = STATUS_KEYS.to_h { |status| [status, files.count { |file| file.status.to_s == status }] }
      {
        "available" => true,
        "files_changed" => files.length,
        "lines_added" => lines_added,
        "lines_removed" => lines_removed,
        "status_counts" => status_counts
      }
    end
    private_class_method :change

    def line_total(files, attribute)
      values = files.map { |file| file.public_send(attribute) }
      return 0 if values.empty?
      return nil unless values.all? { |value| value.is_a?(Integer) && value >= 0 }

      values.sum
    end
    private_class_method :line_total

    def signals(git_context)
      paths = if git_context
        git_context.changed_files.flat_map { |file| [file.path, file.old_path, file.new_path] }.compact.uniq.sort
      else
        []
      end
      available = !git_context.nil?

      SIGNALS.to_h do |name, matcher|
        evidence = available ? paths.select { |path| matcher.call(path) } : []
        evidence_head = evidence.first(MAX_SIGNAL_EVIDENCE)
        entry = {
          "available" => available,
          "present" => !evidence.empty?,
          "evidence" => evidence_head,
          "additional_evidence_count" => [evidence.length - evidence_head.length, 0].max
        }
        entry["reason"] = "git_scope_unavailable" unless available
        [name, entry]
      end
    end
    private_class_method :signals

    def quality_delta(result)
      comparison = result.comparison
      baseline = result.baseline
      unless baseline && baseline["loaded"] == true && comparison.is_a?(Hash)
        return { "available" => false, "reason" => baseline && baseline["compatible"] == false ? "baseline_incompatible" : "baseline_not_available" }
      end

      counts = comparison.fetch("counts", {})
      {
        "available" => true,
        "introduced" => counts.fetch("introduced", 0),
        "existing" => counts.fetch("existing", 0),
        "resolved" => counts.fetch("resolved", 0),
        "changed" => counts.fetch("changed", 0),
        "moved" => counts.fetch("moved", 0),
        "waived" => counts.fetch("waived", 0),
        "orphaned_waivers" => Array(comparison["orphaned_waivers"]).length
      }
    end
    private_class_method :quality_delta

    def analyzer_evidence(result)
      result.analyzer_results.sort_by(&:analyzer).map do |analyzer|
        entry = {
          "analyzer" => analyzer.analyzer,
          "execution_status" => analyzer.execution_status,
          "evidence_status" => analyzer.evidence_status
        }
        entry["tool_version"] = analyzer.tool_version if analyzer.tool_version
        entry
      end
    end
    private_class_method :analyzer_evidence

    def test_intelligence(result)
      analyzers = {}
      result.analyzer_results.sort_by(&:analyzer).each do |analyzer|
        next unless %w[minitest rspec].include?(analyzer.analyzer)
        next unless analyzer.execution_status == "succeeded" && analyzer.evidence_summary.is_a?(Hash)

        summary = analyzer.evidence_summary
        analyzers[analyzer.analyzer] = TEST_KEYS.each_with_object({}) do |key, values|
          values[key] = summary[key] if summary.key?(key)
        end
      end
      return { "available" => false, "reason" => "test_metrics_unavailable" } if analyzers.empty?

      { "available" => true, "analyzers" => analyzers }
    end
    private_class_method :test_intelligence

    def coverage(result)
      analyzer = result.analyzer_results.find { |item| item.analyzer == "simplecov" }
      summary = analyzer&.evidence_summary
      unless analyzer&.execution_status == "succeeded" && summary.is_a?(Hash)
        return { "available" => false, "reason" => "coverage_evidence_unavailable" }
      end

      output = { "available" => true }
      output["global_percent"] = summary["percent"] if summary["percent"].is_a?(Numeric)
      changed = summary["changed_line_coverage"]
      if changed.is_a?(Hash) && changed["percent"].is_a?(Numeric)
        output["changed_lines_percent"] = changed["percent"]
        output["changed_lines_covered"] = changed["covered_lines"] if changed["covered_lines"].is_a?(Integer)
        output["changed_lines_executable"] = changed["executable_lines"] if changed["executable_lines"].is_a?(Integer)
      end
      output
    end
    private_class_method :coverage
  end
end
