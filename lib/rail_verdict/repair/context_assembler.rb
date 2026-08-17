# frozen_string_literal: true

require "digest"
require "json"

module RailVerdict
  module Repair
    module ContextAssembler
      MAX_PACKET_BYTES = 256 * 1024

      class StaleFindingError < RailVerdict::Error; end

      def self.build(outcome:, finding_ref:, repository_root: nil, runner: nil, ai_analysis: nil, clock: Time.now.utc)
        raise ArgumentError, "outcome required" unless outcome
        raise ArgumentError, "finding_ref required" if finding_ref.to_s.strip.empty?

        findings = outcome.findings || []
        target = findings.find { |f| f.id == finding_ref || f.fingerprint == finding_ref }
        raise StaleFindingError, "finding not found: #{finding_ref}" unless target

        configuration = outcome.configuration
        result = outcome.result
        context = outcome.context

        root = repository_root || context&.repository_root || Dir.pwd
        runner ||= ProcessRunner.new

        blocking = blocking_for(result, target)
        finding_state = target.state

        analyzer_result = analyzer_result_for(result, target)
        evidence = build_evidence(target, analyzer_result)
        git_ctx = build_git_context(result, context, target)
        rails = build_rails_context(result)
        source_ctx = build_source_context(root, target)
        diff = build_diff(root, runner, target, context)

        verification = build_verification(result, configuration)
        policy = {
          "mode" => configuration&.mode || "strict",
          "configuration_digest" => configuration&.digest || Digest::SHA256.hexdigest("")
        }
        baseline_state = build_baseline_state(root, configuration)
        waivers_state = build_waivers_state(root, configuration)
        boundary = Boundary.snapshot(repository_root: root, configuration: configuration, outcome: outcome)
        base_for_plan = begin; result&.git&.fetch("base", nil); rescue StandardError; nil; end
        verification_plan = VerificationPlan.build(outcome: outcome, base_revision: base_for_plan)
        constraints = Constraints.default
        instructions = Constraints.instructions

        source_revision = context&.revision
        base_revision = begin; result&.git&.fetch("base", nil); rescue StandardError; nil; end
        merge_base = begin; result&.git&.fetch("merge_base", nil); rescue StandardError; nil; end

        analyzer_versions = context&.analyzer_versions || {}
        baseline_digest = boundary["baseline_digest"]
        packet_id = Packet.packet_id_for(
          fingerprint: target.fingerprint,
          source_revision: source_revision,
          base_revision: base_revision,
          configuration_digest: policy["configuration_digest"],
          baseline_digest: baseline_digest,
          analyzer_versions: analyzer_versions
        )

        truncated = source_ctx["truncated"] || diff["truncated"] || rails["truncated"] || false
        completeness = {
          "deterministic" => "complete",
          "repair_context" => truncated ? "partial" : "complete",
          "truncated" => truncated
        }
        gate = result&.gate || "FAIL"
        success = {
          "description" => "Target finding no longer blocking and gate is PASS/WARN with complete verification and unchanged boundary.",
          "gate_must_be" => %w[PASS WARN],
          "target_must_be_fixed" => true,
          "completion_must_be" => "complete",
          "boundary_must_be_unchanged" => true
        }

        packet_hash = {
          "schema_version" => Packet::SCHEMA_VERSION,
          "packet_id" => packet_id,
          "created_at" => clock.utc.iso8601,
          "railverdict_version" => RailVerdict::VERSION,
          "source_revision" => source_revision,
          "target" => {
            "finding" => target.to_schema_h,
            "finding_state" => finding_state,
            "blocking" => blocking,
            "severity" => target.severity
          },
          "verification" => verification,
          "evidence" => evidence,
          "git_context" => git_ctx,
          "diff_context" => diff,
          "rails_context" => rails,
          "source_context" => source_ctx,
          "policy" => policy,
          "baseline_state" => baseline_state,
          "waivers_state" => waivers_state,
          "verification_plan" => verification_plan,
          "constraints" => constraints,
          "instructions" => instructions,
          "completeness" => completeness,
          "success_criteria" => success,
          "boundary" => boundary
        }
        packet_hash["base_revision"] = base_revision unless base_revision.nil?
        packet_hash["merge_base"] = merge_base unless merge_base.nil?
        packet_hash["ai_analysis"] = ai_analysis.to_h if ai_analysis

        errors = SchemaValidator.validate_repair_packet(packet_hash)
        raise ArgumentError, "invalid packet: #{errors.join('; ')}" unless errors.empty?

        if JSON.generate(packet_hash).bytesize > MAX_PACKET_BYTES
          packet_hash["source_context"] = { "snippets" => packet_hash["source_context"]["snippets"].first(1), "truncated" => true }
          packet_hash["diff_context"] = { "hunk" => packet_hash["diff_context"]["hunk"].byteslice(0, 4096).to_s, "truncated" => true }
          packet_hash["completeness"] = { "deterministic" => "complete", "repair_context" => "partial", "truncated" => true }
        end

        Packet.new(
          packet_id: packet_hash["packet_id"],
          created_at: packet_hash["created_at"],
          railverdict_version: packet_hash["railverdict_version"],
          source_revision: packet_hash["source_revision"],
          base_revision: packet_hash["base_revision"],
          merge_base: packet_hash["merge_base"],
          target: packet_hash["target"],
          verification: packet_hash["verification"],
          evidence: packet_hash["evidence"],
          git_context: packet_hash["git_context"],
          diff_context: packet_hash["diff_context"],
          rails_context: packet_hash["rails_context"],
          source_context: packet_hash["source_context"],
          policy: packet_hash["policy"],
          baseline_state: packet_hash["baseline_state"],
          waivers_state: packet_hash["waivers_state"],
          ai_analysis: packet_hash["ai_analysis"],
          verification_plan: packet_hash["verification_plan"],
          constraints: packet_hash["constraints"],
          instructions: packet_hash["instructions"],
          completeness: packet_hash["completeness"],
          success_criteria: packet_hash["success_criteria"],
          boundary: packet_hash["boundary"]
        )
      end

      def self.blocking_for(result, finding)
        summary = result&.findings&.find { |f| f["fingerprint"] == finding.fingerprint }
        return summary["blocking"] unless summary.nil?

        true
      end
      private_class_method :blocking_for

      def self.analyzer_result_for(result, finding)
        (result&.analyzer_results || []).find { |ar| ar.analyzer == finding.analyzer }
      end
      private_class_method :analyzer_result_for

      def self.build_evidence(finding, analyzer_result)
        {
          "analyzer" => finding.analyzer,
          "tool_version" => analyzer_result&.tool_version,
          "rule_id" => finding.rule_id,
          "location" => finding.location,
          "message" => finding.message,
          "evidence_summary" => analyzer_result&.evidence_summary || {}
        }.compact
      end
      private_class_method :build_evidence

      def self.build_verification(result, configuration)
        {
          "gate" => result&.gate || "FAIL",
          "policy_status" => result&.policy_status || "fail",
          "mode" => configuration&.mode || "strict",
          "decision_reasons" => result&.decision_reasons || [],
          "comparison_counts" => result&.comparison&.fetch("counts", {}) || {}
        }
      end
      private_class_method :build_verification

      def self.build_git_context(result, context, finding)
        git = result&.git || {}
        path = finding.location["path"]
        changed_lines = []
        changed_file = nil
        rename = nil
        if context&.git_context
          gc = context.git_context
          changed_file = gc.changed_files.find { |f| f.path == path }
          if changed_file
            changed_file_h = { "path" => changed_file.path, "status" => changed_file.status.to_s, "score" => changed_file.score }
            changed_file_h["old_path"] = changed_file.old_path if changed_file.old_path
            changed_file_h["new_path"] = changed_file.new_path if changed_file.new_path
            changed_file_h["binary"] = changed_file.binary if changed_file.respond_to?(:binary)
            changed_file = changed_file_h
          end
          changed_lines = (gc.changed_line_set[path] || []).sort
          if changed_file && changed_file["old_path"]
            rename = { "new_path" => path, "old_path" => changed_file["old_path"] }
          end
        end
        {
          "head" => git["head"],
          "base" => git["base"],
          "merge_base" => git["merge_base"],
          "changed_file" => changed_file,
          "changed_lines_for_target" => changed_lines,
          "rename" => rename
        }
      end
      private_class_method :build_git_context

      def self.build_rails_context(result)
        rc = result&.rails_context || {}
        detected = rc["detected"] || {}
        entries = rc["entries"] || []
        truncated = entries.length > 20
        {
          "detected" => detected,
          "entry" => entries.first,
          "related" => Array(entries.first&.fetch("related", nil)).first(20) || [],
          "truncated" => truncated
        }
      rescue StandardError
        { "detected" => {}, "entry" => nil, "related" => [], "truncated" => false }
      end
      private_class_method :build_rails_context

      def self.build_source_context(root, finding)
        path = finding.location["path"]
        line = finding.location["start_line"]
        snippets = []
        if path
          raw = Intelligence::SourceReader.read_snippet(repository_root: root, path: path, target_line: line)
          if raw
            content = raw[:content].to_s
            if Intelligence::SecretDetector.content_secret?(content) || Intelligence::SecretDetector.filename_secret?(path)
              content = "[REDACTED: probable secret detected]"
            end
            content = content.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "?")
            snippets << { "path" => raw[:path], "content" => content, "truncated" => raw[:truncated] }
          end
        end
        { "snippets" => snippets, "truncated" => snippets.any? { |s| s["truncated"] } }
      rescue StandardError
        { "snippets" => [], "truncated" => false }
      end
      private_class_method :build_source_context

      def self.build_diff(root, runner, finding, context)
        git_ctx = context&.git_context
        return { "hunk" => "", "truncated" => false } unless git_ctx

        h = DiffContext.build(repository_root: root, runner: runner, finding: finding, git_context: git_ctx)
        h["hunk"] = h["hunk"].encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "?") rescue h["hunk"]
        if Intelligence::SecretDetector.content_secret?(h["hunk"])
          h["hunk"] = "[REDACTED: probable secret detected]"
          h["truncated"] = true
        end
        h
      rescue StandardError
        { "hunk" => "", "truncated" => false }
      end
      private_class_method :build_diff

      def self.build_baseline_state(root, configuration)
        return { "loaded" => false, "path" => nil, "digest" => nil } unless configuration

        path = Baseline.resolve_path(repository_root: root, configuration: configuration)
        digest = Boundary.file_digest(path) rescue nil
        loaded = !digest.nil?
        { "loaded" => loaded, "path" => path, "digest" => digest }
      rescue StandardError
        { "loaded" => false, "path" => nil, "digest" => nil }
      end
      private_class_method :build_baseline_state

      def self.build_waivers_state(root, configuration)
        return { "count" => 0, "path" => nil, "digest" => nil } unless configuration

        path = WaiverStore.resolve_path(repository_root: root, configuration: configuration)
        digest = Boundary.file_digest(path) rescue nil
        count = 0
        begin
          waivers = WaiverStore.read_optional(path)
          count = waivers.length
        rescue StandardError
          count = 0
        end
        { "count" => count, "path" => path, "digest" => digest }
      rescue StandardError
        { "count" => 0, "path" => nil, "digest" => nil }
      end
      private_class_method :build_waivers_state
    end
  end
end
