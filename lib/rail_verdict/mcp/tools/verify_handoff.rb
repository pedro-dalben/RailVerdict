# frozen_string_literal: true

module RailVerdict
  module MCP
    module Tools
      class VerifyHandoff
        def initialize(server:)
          @server = server
        end

        def tool_name
          "verify_handoff"
        end

        def tool_title
          "Verify handoff reuse"
        end

        def tool_description
          "Evaluate whether a Verification Handoff is REUSABLE under current repository state/environment. Re-observes state/environment independently, never trusts Handoff. Returns REUSABLE or VERIFICATION_REQUIRED with reasons. Does not execute analyzers."
        end

        def tool_input_schema
          {
            type: "object",
            properties: {
              handoff: { type: "object", description: "Handoff document" },
              handoff_json: { type: "string", description: "Handoff JSON string" },
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
              handoff_valid: { type: "boolean" },
              receipt_fresh: { type: "boolean" },
              decision: { type: "string", enum: %w[REUSABLE VERIFICATION_REQUIRED INVALID UNAVAILABLE] },
              reasons: { type: "array" },
              handoff_id: { type: "string" },
              receipt_id: { type: "string" }
            },
            required: %w[decision]
          }
        end

        def tool_annotations
          { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false, title: tool_title }
        end

        def call(handoff: nil, handoff_json: nil, config_path: nil, baseline_path: nil, waiver_path: nil, **_rest)
          text = if handoff_json && !handoff_json.to_s.strip.empty?
                   handoff_json.to_s
                 elsif handoff
                   JSON.generate(handoff)
                 else
                   return Serializers.error_response("handoff or handoff_json required", code: "invalid_arguments")
                 end
          return Serializers.error_response("handoff too large", code: "handoff_too_large") if text.bytesize > Handoff::MAX_DOCUMENT_BYTES
          doc, err = Handoff.parse(text)
          unless doc
            return Serializers.tool_response({ "handoff_valid" => false, "receipt_fresh" => false, "decision" => Reuse::INVALID, "reasons" => [err.to_s] }, error: false)
          end

          root = @server.repository_root
          effective_paths = Check.effective_input_paths(root: File.realpath(root), config_path: resolve_config_path(config_path), baseline_path_override: resolve_contained_path(baseline_path, "baseline_path"), waiver_path_override: resolve_contained_path(waiver_path, "waiver_path"))
          before_state = RepositoryState.capture(repository_root: root, configuration_paths: effective_paths)
          current_env_obj = VerificationEnvironment.capture(repository_root: root)
          current_env = {
            "ruby_engine" => current_env_obj.ruby_engine,
            "ruby_version" => current_env_obj.ruby_version,
            "railverdict_version" => current_env_obj.railverdict_version,
            "analyzer_versions" => current_env_obj.analyzer_versions
          }
          config = Configuration.load(effective_paths[:config]) rescue nil
          required = config ? config.analyzers.select { |_, s| s["enabled"] && s["required"] }.keys.map(&:to_s) : []
          contract = { "required_analyzers" => required, "verification_mode" => doc.dig("source_scope", "verification_mode"), "changed_base" => doc.dig("source_scope", "changed_base") }
          result = Reuse.evaluate(handoff_document: doc, current_repository_state: before_state, current_environment: current_env, current_contract: contract)
          after_state = RepositoryState.capture(repository_root: root, configuration_paths: effective_paths)
          if before_state && after_state && before_state.digest != after_state.digest
            result = Reuse::Result.new(decision: Reuse::VERIFICATION_REQUIRED, reasons: result.reasons + ["reuse_toctou"], handoff_valid: result.handoff_valid, receipt_fresh: result.receipt_fresh)
          end
          Serializers.tool_response({ "handoff_valid" => result.handoff_valid, "receipt_fresh" => result.receipt_fresh, "decision" => result.decision, "reasons" => result.reasons, "handoff_id" => doc["handoff_id"], "receipt_id" => doc.dig("receipt", "receipt_id") }, error: false)
        rescue ArgumentError => e
          Serializers.error_response(e.message, code: "invalid_arguments")
        rescue StandardError => e
          Serializers.error_response("verify_handoff failed: #{e.message}", code: "internal_error")
        end

        private

        def resolve_contained_path(raw_path, field_name)
          return nil if raw_path.nil? || raw_path.to_s.strip.empty?
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
