# frozen_string_literal: true

module RailVerdict
  module MCP
    module Tools
      class ListFindings
        def initialize(server:)
          @server = server
        end

        def tool_name
          "list_findings"
        end

        def tool_title
          "List findings"
        end

        def tool_description
          "List deterministic findings from the last verification. Supports filtering by severity/state/blocking and pagination via limit/offset. Stable ordering by path/start_line/analyzer/rule/fingerprint/id. Truncated flag is explicit."
        end

        def tool_input_schema
          {
            type: "object",
            properties: {
              limit: { type: "integer", description: "Max findings to return (1..100, default 50)" },
              offset: { type: "integer", description: "Offset (default 0)" },
              severity: { type: "string", enum: %w[info low medium high critical], description: "Filter by severity" },
              state: { type: "string", enum: %w[observed introduced existing resolved changed moved suppressed waived], description: "Filter by state" },
              blocking: { type: "boolean", description: "Filter by blocking" }
            },
            additionalProperties: false
          }
        end

        def tool_output_schema
          {
            type: "object",
            properties: {
              findings: { type: "array" },
              total: { type: "integer" },
              limit: { type: "integer" },
              offset: { type: "integer" },
              truncated: { type: "boolean" },
              gate: { type: "string" },
              completion_status: { type: "string" }
            },
            required: %w[findings total limit offset truncated]
          }
        end

        def tool_annotations
          { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false, title: tool_title }
        end

        def call(limit: nil, offset: nil, severity: nil, state: nil, blocking: nil, **_rest)
          begin
            limit_v = Validators.validate_limit(limit, default: 50, max: 100)
            offset_v = Validators.validate_offset(offset)
            severity_v = Validators.validate_severity(severity)
            state_v = Validators.validate_state(state)

            outcome = @server.cache.fetch_outcome
            unless outcome
              outcome = run_verify
              @server.cache.store_outcome(outcome)
            end

            findings = outcome.findings || []
            if severity_v
              findings = findings.select { |f| f.severity == severity_v }
            end
            if state_v
              gate_findings = outcome.result.findings
              allowed_fps = gate_findings.select { |h| h["state"] == state_v }.map { |h| h["fingerprint"] }.to_set
              findings = findings.select { |f| allowed_fps.include?(f.fingerprint) }
            end
            unless blocking.nil?
              gate_findings = outcome.result.findings
              allowed_fps = gate_findings.select { |h| h["blocking"] == blocking }.map { |h| h["fingerprint"] }.to_set
              findings = findings.select { |f| allowed_fps.include?(f.fingerprint) }
            end

            findings = findings.sort_by(&:sort_key)
            total = findings.length
            if offset_v > total
              return Serializers.error_response("offset exceeds total (#{total})", code: "invalid_arguments")
            end
            slice = findings.slice(offset_v, limit_v) || []
            truncated = (offset_v + limit_v) < total

            structured = {
              "findings" => slice.map(&:to_schema_h),
              "total" => total,
              "limit" => limit_v,
              "offset" => offset_v,
              "truncated" => truncated,
              "gate" => outcome.result.gate,
              "completion_status" => outcome.result.completion_status
            }
            structured = Serializers.scrub(structured)
            Serializers.tool_response(structured, error: false)
          rescue ArgumentError => e
            Serializers.error_response(e.message, code: "invalid_arguments")
          rescue StandardError => e
            Serializers.error_response("list_findings failed: #{e.message}", code: "internal_error")
          end
        end

        private

        def run_verify
          Check.execute(repository_root: @server.repository_root, config_path: File.join(@server.repository_root, ".railverdict.yml"))
        end
      end
    end
  end
end
