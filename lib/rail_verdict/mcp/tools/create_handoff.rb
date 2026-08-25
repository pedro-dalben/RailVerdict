# frozen_string_literal: true

module RailVerdict
  module MCP
    module Tools
      class CreateHandoff
        def initialize(server:)
          @server = server
        end

        def tool_name
          "create_handoff"
        end

        def tool_title
          "Create verification handoff"
        end

        def tool_description
          "Create a deterministic Verification Handoff (bounded transport envelope) from a fresh verification. Runs verification, builds receipt and handoff. Offline, file/process usable, fail-closed. Handoff never self-authorizes reuse."
        end

        def tool_input_schema
          {
            type: "object",
            properties: {
              changed: { type: "boolean" },
              base: { type: "string" },
              config_path: { type: "string" },
              baseline_path: { type: "string" },
              waiver_path: { type: "string" }
            },
            additionalProperties: false
          }
        end

        def tool_output_schema
          {
            type: "object",
            properties: {
              handoff: { type: "object" },
              receipt: { type: "object" },
              handoff_id: { type: "string" }
            },
            required: %w[handoff]
          }
        end

        def tool_annotations
          { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false, title: tool_title }
        end

        def call(changed: nil, base: nil, config_path: nil, baseline_path: nil, waiver_path: nil, **_rest)
          changed = changed == true
          base_validated = Validators.validate_base_revision(base)
          return Serializers.error_response("--base requires --changed", code: "invalid_arguments") if base_validated && !changed

          config_file = resolve_config_path(config_path)
          outcome = @server.synchronized_verification { run_check(changed: changed, base: base_validated, config_path: config_file, baseline_path: baseline_path, waiver_path: waiver_path) }
          receipt = Receipt.build(outcome: outcome)
          evidence_set = {
            "analyzer_results" => outcome.result.analyzer_results.map do |ar|
              h = { "analyzer" => ar.analyzer, "execution_status" => ar.execution_status, "tool_version" => ar.tool_version }
              findings = outcome.findings.select { |f| f.analyzer == ar.analyzer }.map(&:to_schema_h).sort_by { |ff| ff["fingerprint"] }
              h["findings"] = findings if findings.any?
              h
            end
          }
          provenance = { "analyzer_versions" => outcome.context&.analyzer_versions || {} }
          scope = { "verification_mode" => outcome.result.git ? "changed" : "full", "changed_base" => outcome.result.git && outcome.result.git["base"], "changed_merge_base" => outcome.result.git && outcome.result.git["merge_base"] }
          handoff = Handoff.build(receipt: receipt, evidence_set: evidence_set, evidence_provenance: provenance, source_scope: scope)
          @server.cache.store_handoff(handoff) if @server.cache.respond_to?(:store_handoff)
          Serializers.tool_response({ "handoff" => Serializers.scrub(handoff), "receipt" => Serializers.scrub(receipt), "handoff_id" => handoff["handoff_id"] }, error: false)
        rescue Handoff::BuildError, Receipt::BuildError => e
          Serializers.error_response("#{e.code}: #{e.message}", code: e.code)
        rescue ArgumentError => e
          Serializers.error_response(e.message, code: "invalid_arguments")
        rescue StandardError => e
          Serializers.error_response("create_handoff failed: #{e.message}", code: "internal_error")
        end

        private

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
          raise ArgumentError, "#{field_name} escapes repository root" unless RepositoryRoot.contained?(@server.repository_root, expanded)
          expanded
        end

        def resolve_config_path(config_path)
          return File.join(@server.repository_root, ".railverdict.yml") if config_path.nil? || config_path.to_s.strip.empty?
          raw = config_path.to_s.strip
          raise ArgumentError, "config_path contains NUL byte" if raw.include?("\u0000")
          expanded = File.expand_path(raw, @server.repository_root)
          raise ArgumentError, "config_path escapes repository root" unless RepositoryRoot.contained?(@server.repository_root, expanded)
          expanded
        end
      end
    end
  end
end
