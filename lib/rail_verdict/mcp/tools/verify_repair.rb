# frozen_string_literal: true

module RailVerdict
  module MCP
    module Tools
      class VerifyRepair
        def initialize(server:)
          @server = server
        end

        def tool_name
          "verify_repair"
        end

        def tool_title
          "Verify repair"
        end

        def tool_description
          "Verify whether a prior RepairPacket target is fixed. Re-runs verification and classifies target_status (fixed/still_present/changed/moved/regressed/incomplete) plus verification_boundary_changed and gate. Never trusts agent-provided fixed claim."
        end

        def tool_input_schema
          {
            type: "object",
            properties: {
              packet_id: { type: "string", description: "Packet id (sha256:...); must match a prior build_repair_packet packet_id in this server session" },
              changed: { type: "boolean", description: "Re-verify with Git changed scope" },
              base: { type: "string", description: "Base revision for re-verify (hex SHA) when changed is true" }
            },
            required: ["packet_id"],
            additionalProperties: false
          }
        end

        def tool_output_schema
          nil
        end

        def tool_annotations
          { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false, title: tool_title }
        end

        def call(packet_id: nil, changed: nil, base: nil, **_rest)
          begin
            pid = Validators.validate_packet_id(packet_id)
            changed_v = changed == true
            base_v = Validators.validate_base_revision(base)
            if base_v && !changed_v
              return Serializers.error_response("--base requires --changed", code: "invalid_arguments")
            end

            packet_h = @server.cache.fetch_packet(pid)
            unless packet_h
              return Serializers.error_response("packet not found for packet_id: #{pid}; call build_repair_packet first", code: "stale_target")
            end

            fresh_outcome = fresh_check(changed: changed_v, base: base_v)
            result = Repair::Verifier.verify(packet: packet_h, new_outcome: fresh_outcome)

            structured = {
              "target_status" => result.target_status,
              "gate" => result.gate,
              "completion_status" => result.completion_status,
              "new_blocking_findings" => result.new_blocking_findings,
              "verification_boundary_changed" => result.verification_boundary_changed,
              "regressed" => result.regressed,
              "gate_result" => fresh_outcome.result.to_schema_h
            }
            structured = Serializers.scrub(structured)
            Serializers.tool_response(structured, error: false)
          rescue ArgumentError => e
            Serializers.error_response(e.message, code: "invalid_arguments")
          rescue StandardError => e
            Serializers.error_response("verify_repair failed: #{e.message}", code: "internal_error")
          end
        end

        private

        def fresh_check(changed:, base:)
          root = @server.repository_root
          opts = { repository_root: root, config_path: File.join(root, ".railverdict.yml") }
          opts[:changed] = true if changed
          opts[:base] = base if base
          Check.execute(**opts)
        end
      end
    end
  end
end
