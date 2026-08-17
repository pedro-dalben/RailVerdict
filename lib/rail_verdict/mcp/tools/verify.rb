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
          nil
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

            outcome = run_check(changed: changed, base: base_validated, config_path: config_file, baseline_path: baseline_path, waiver_path: waiver_path)
            @server.cache.store_outcome(outcome)
            structured = Serializers.gate_result_to_structured(outcome)
            structured = Validators.scrub_text(structured) if structured.is_a?(String)
            structured = Serializers.scrub(structured)
            Serializers.tool_response(structured, error: false)
          rescue ArgumentError => e
            Serializers.error_response(e.message, code: "invalid_arguments")
          rescue StandardError => e
            Serializers.error_response("verify failed: #{e.message}", code: "internal_error")
          end
        end

        private

        def run_check(changed:, base:, config_path:, baseline_path:, waiver_path:)
          root = @server.repository_root
          opts = { repository_root: root, config_path: config_path }
          opts[:changed] = true if changed
          opts[:base] = base if base
          opts[:baseline_path_override] = baseline_path if baseline_path && !baseline_path.to_s.strip.empty?
          opts[:waiver_path_override] = waiver_path if waiver_path && !waiver_path.to_s.strip.empty?
          Check.execute(**opts)
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
