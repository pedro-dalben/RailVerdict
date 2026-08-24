# frozen_string_literal: true

module RailVerdict
  module MCP
    module Tools
      class Verify
        def initialize(server:)
          @server = server
        end

        def tool_name
          "verify"
        end

        def tool_title
          "Verify repository"
        end

        def tool_description
          "Deterministic read-only verification. Runs RailVerdict Check and returns GateResult (PASS/WARN/FAIL/INCOMPLETE). FAIL is a successful result (isError false) — not a protocol error. Works offline with no network. Requires no AI."
        end

        def tool_input_schema
          {
            type: "object",
            properties: {
              changed: { type: "boolean", description: "Use Git changed scope (--changed)" },
              base: { type: "string", description: "Base revision for --changed (hex SHA 7..64)" },
              config_path: { type: "string", description: "Path to .railverdict.yml relative to repository root" },
              baseline_path: { type: "string", description: "Override baseline path" },
              waiver_path: { type: "string", description: "Override waivers path" }
            },
            additionalProperties: false
          }
        end

        def tool_output_schema
          {
            type: "object",
            properties: {
              schema_version: { type: "string" },
              completion_status: { type: "string" },
              gate: { type: "string" },
              policy_status: { type: "string" },
              findings: { type: "array" },
              analyzer_results: { type: "array" },
              operational_failures: { type: "array" },
              decision_reasons: { type: "array" }
            },
            required: %w[schema_version completion_status gate policy_status findings]
          }
        end

        def tool_annotations
          { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false, title: tool_title }
        end

        def call(changed: nil, base: nil, config_path: nil, baseline_path: nil, waiver_path: nil, **_rest)
          begin
            changed = changed == true
            base_validated = Validators.validate_base_revision(base)
            if base_validated && !changed
              return Serializers.error_response("--base requires --changed", code: "invalid_arguments")
            end
            config_file = resolve_config_path(config_path)
            if changed
              base_for_check = base_validated || configuration_git_base(config_file)
              if base_for_check.nil? || base_for_check.strip.empty?
                # Let Check handle git_scope_failed as INCOMPLETE — still need a base, but we try check anyway
              end
            end

            outcome = @server.synchronized_verification { run_check(changed: changed, base: base_validated, config_path: config_file, baseline_path: baseline_path, waiver_path: waiver_path) }
            receipt_document = build_receipt_document(outcome)
            pr_intelligence_document = build_pr_intelligence_document(outcome)
            @server.cache.store_verification(outcome: outcome, receipt_document: receipt_document, pr_intelligence_document: pr_intelligence_document)
            structured = Serializers.gate_result_to_structured(outcome)
            structured = Validators.scrub_text(structured) if structured.is_a?(String)
            structured = Serializers.scrub(structured)
            if receipt_document.is_a?(Hash) && structured.is_a?(Hash)
              structured["verification_receipt"] = Serializers.scrub(receipt_document)
            end
            Serializers.tool_response(structured, error: false)
          rescue ArgumentError => e
            Serializers.error_response(e.message, code: "invalid_arguments")
          rescue StandardError => e
            Serializers.error_response("verify failed: #{e.message}", code: "internal_error")
          end
        end

        private

        # One canonical Check execution per verify call; the receipt and PR
        # Intelligence are derived from that same outcome — analyzers never run
        # twice for one verification.
        def build_receipt_document(outcome)
          RailVerdict::Receipt.build(
            outcome: outcome,
            pr_intelligence_document: (pr_intelligence_document(outcome) rescue nil)
          )
        rescue RailVerdict::Receipt::BuildError => error
          {"status" => "unavailable", "code" => error.code}
        end

        def pr_intelligence_document(outcome)
          return nil unless outcome.context&.git_context || outcome.result.git.is_a?(Hash)

          PRIntelligence.document(outcome)
        end

        def build_pr_intelligence_document(outcome)
          pr_intelligence_document(outcome)
        rescue StandardError
          nil
        end

        def run_check(changed:, base:, config_path:, baseline_path:, waiver_path:)
          root = @server.repository_root
          opts = { repository_root: root, config_path: config_path }
          opts[:changed] = true if changed
          opts[:base] = base if base
          baseline_resolved = resolve_contained_path(baseline_path, "baseline_path") if baseline_path && !baseline_path.to_s.strip.empty?
          waiver_resolved = resolve_contained_path(waiver_path, "waiver_path") if waiver_path && !waiver_path.to_s.strip.empty?
          opts[:baseline_path_override] = baseline_resolved if baseline_resolved
          opts[:waiver_path_override] = waiver_resolved if waiver_resolved
          Check.execute_with_state_guard(**opts)
        end

        def resolve_contained_path(raw_path, field_name)
          raw = raw_path.to_s.strip
          raise ArgumentError, "#{field_name} contains NUL byte" if raw.include?("\u0000")

          expanded = File.expand_path(raw, @server.repository_root)
          unless RepositoryRoot.contained?(@server.repository_root, expanded)
            raise ArgumentError, "#{field_name} escapes repository root"
          end
          expanded
        end

        def resolve_config_path(config_path)
          return File.join(@server.repository_root, ".railverdict.yml") if config_path.nil? || config_path.to_s.strip.empty?

          raw = config_path.to_s.strip
          raise ArgumentError, "config_path contains NUL byte" if raw.include?("\u0000")

          expanded = File.expand_path(raw, @server.repository_root)
          unless RepositoryRoot.contained?(@server.repository_root, expanded)
            raise ArgumentError, "config_path escapes repository root"
          end
          expanded
        end

        def configuration_git_base(config_file)
          return nil unless File.file?(config_file)

          begin
            cfg = Configuration.load(config_file)
            cfg.git_base
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
