# frozen_string_literal: true

module RailVerdict
  module Intelligence
    module ContextBuilder
      MAX_FILES = 3
      MAX_CONTEXT_BYTES = 64 * 1024

      def self.build(outcome:, finding_ref:, repository_root: nil)
        root = repository_root || outcome.context&.repository_root || Dir.pwd
        findings = outcome.findings || []
        target = findings.find { |f| f.id == finding_ref || f.fingerprint == finding_ref }
        raise ArgumentError, "finding not found: #{finding_ref}" unless target

        location = target.location || {}
        path = location["path"] || location[:path]
        line = location["start_line"] || location[:start_line]

        snippets = []
        if path
          snippet = SourceReader.read_snippet(repository_root: root, path: path, target_line: line)
          snippets << snippet if snippet
        end
        snippets = snippets.first(MAX_FILES)

        rails_facts = extract_rails_facts(outcome, path)
        git_slice = extract_git_slice(outcome)
        comparison_slice = extract_comparison(outcome)
        policy_reason = outcome.result&.decision_reasons&.first&.fetch("message", nil) rescue nil

        manifest = Manifest.new(
          finding_id: target.id,
          fingerprint: target.fingerprint,
          finding: target.to_schema_h,
          snippets: snippets.map { |s| { "path" => s[:path], "content" => sanitize(s[:content]), "truncated" => s[:truncated] } },
          rails_facts: rails_facts,
          git_slice: git_slice,
          comparison_slice: comparison_slice,
          policy_reason: policy_reason
        )

        if manifest.total_bytes > MAX_CONTEXT_BYTES
          trimmed = Manifest.new(
            finding_id: manifest.finding_id,
            fingerprint: manifest.fingerprint,
            finding: manifest.finding,
            snippets: manifest.snippets.first(1).map { |s| s.merge("content" => s["content"].byteslice(0, 16 * 1024).to_s) },
            rails_facts: rails_facts.is_a?(Array) ? rails_facts.first(1) : rails_facts,
            git_slice: git_slice,
            comparison_slice: comparison_slice,
            policy_reason: policy_reason
          )
          return trimmed
        end

        manifest
      end

      def self.extract_rails_facts(outcome, path)
        rc = outcome.result&.instance_variable_get(:@rails_context) rescue nil
        rc ||= outcome.result&.to_schema_h&.fetch("rails_context", nil) rescue nil
        return [] unless rc

        entries = rc["entries"] || rc[:entries] || []
        return entries unless path

        entries.select { |e| (e["source_path"] || e[:source_path]) == path }.first(1)
      end

      def self.extract_git_slice(outcome)
        git = outcome.result&.instance_variable_get(:@git) rescue nil
        return {} unless git

        { "head" => git["head"], "base" => git["base"], "merge_base" => git["merge_base"] }
      end

      def self.extract_comparison(outcome)
        comp = outcome.result&.instance_variable_get(:@comparison) rescue nil
        return {} unless comp

        { "counts" => comp["counts"] }
      end

      def self.sanitize(text)
        t = text.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")
        t = t.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "?")
        t
      end
      private_class_method :sanitize
    end
  end
end
