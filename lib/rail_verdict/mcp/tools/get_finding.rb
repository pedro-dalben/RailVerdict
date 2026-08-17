# frozen_string_literal: true

module RailVerdict
  module MCP
    module Tools
      class GetFinding
        def initialize(server:)
          @server = server
        end

        def tool_name
          "get_finding"
        end

        def tool_title
          "Get finding"
        end

        def tool_description
          "Retrieve a single finding by id (rv:...) or fingerprint (sha256:...) with bounded context (git slice, rails slice, evidence summary). Finding ID must be exact; no fuzzy match."
        end

        def tool_input_schema
          {
            type: "object",
            properties: {
              finding_ref: { type: "string", description: "Finding id (rv:...) or fingerprint (sha256:...)" }
            },
            required: ["finding_ref"],
            additionalProperties: false
          }
        end

        def tool_output_schema
          nil
        end

        def tool_annotations
          { read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false, title: tool_title }
        end

        def call(finding_ref: nil, **_rest)
          begin
            ref = Validators.validate_finding_ref(finding_ref)
            outcome = @server.cache.fetch_outcome
            unless outcome
              outcome = Check.execute(repository_root: @server.repository_root, config_path: File.join(@server.repository_root, ".railverdict.yml"))
              @server.cache.store_outcome(outcome)
            end

            target = (outcome.findings || []).find { |f| f.id == ref || f.fingerprint == ref }
            unless target
              return Serializers.error_response("finding not found: #{ref}", code: "finding_not_found")
            end

            gate_summary = (outcome.result.findings || []).find { |h| h["fingerprint"] == target.fingerprint }
            evidence = evidence_for(outcome, target)
            git_slice = git_slice_for(outcome, target)
            rails_slice = rails_slice_for(outcome)

            structured = {
              "finding" => target.to_schema_h,
              "gate_summary" => gate_summary,
              "evidence" => evidence,
              "git_context" => git_slice,
              "rails_context" => rails_slice,
              "gate" => outcome.result.gate,
              "completion_status" => outcome.result.completion_status
            }
            structured = Serializers.scrub(structured)
            Serializers.tool_response(structured, error: false)
          rescue ArgumentError => e
            Serializers.error_response(e.message, code: "invalid_arguments")
          rescue StandardError => e
            Serializers.error_response("get_finding failed: #{e.message}", code: "internal_error")
          end
        end

        private

        def evidence_for(outcome, target)
          ar = (outcome.result.analyzer_results || []).find { |r| r.analyzer == target.analyzer }
          {
            "analyzer" => target.analyzer,
            "tool_version" => ar&.tool_version,
            "rule_id" => target.rule_id,
            "location" => target.location,
            "message" => target.message,
            "evidence_summary" => ar&.evidence_summary || {}
          }
        end

        def git_slice_for(outcome, target)
          git = outcome.result.git || {}
          ctx = outcome.context&.git_context
          path = target.location["path"]
          changed_lines = []
          changed_file = nil
          if ctx
            changed_file_obj = ctx.changed_files.find { |f| f.path == path }
            if changed_file_obj
              changed_file = { "path" => changed_file_obj.path, "status" => changed_file_obj.status.to_s, "score" => changed_file_obj.score }
              changed_file["old_path"] = changed_file_obj.old_path if changed_file_obj.old_path
              changed_file["new_path"] = changed_file_obj.new_path if changed_file_obj.new_path
            end
            changed_lines = (ctx.changed_line_set[path] || []).sort
          end
          {
            "head" => git["head"],
            "base" => git["base"],
            "merge_base" => git["merge_base"],
            "changed_file" => changed_file,
            "changed_lines_for_target" => changed_lines
          }
        end

        def rails_slice_for(outcome)
          rc = outcome.result.rails_context || {}
          {
            "detected" => rc["detected"] || {},
            "entry" => rc["entries"] ? rc["entries"].first : rc["entry"]
          }
        end
      end
    end
  end
end
