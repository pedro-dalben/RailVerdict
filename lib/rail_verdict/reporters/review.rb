# frozen_string_literal: true

module RailVerdict
  module Reporters
    # Bounded console projections for review workflow documents.
    # Presentation only: identities live in the JSON documents.
    module Review
      MAX_ROWS = 10

      module_function

      def render_packet(packet)
        det = packet["deterministic"]
        review = packet["review"]
        lines = []
        lines << "Review packet: #{packet['packet_id'].to_s[0, 19]}… " \
                 "(gate #{det['verification']['gate']}, policy #{det['policy']['decision']})"
        lines << "Analyzers executed: #{det['plan']['analyzers_executed'].join(', ')}"
        missing = det["plan"]["analyzers_required_missing"]
        lines << "Analyzers required missing: #{missing.join(', ')}" unless missing.empty?
        lines << "Requirements:"
        det["plan"]["requirements"].each do |entry|
          lines << "  [#{entry['status']}] #{entry['id']}"
        end
        lines << "Recovery:"
        det["recovery"].first(MAX_ROWS).each do |item|
          lines << "  #{item['source']}: #{truncate(item['action'])}"
        end
        lines << "Review risk: #{review['risk_level']}"
        lines << "Review focus:"
        review["focus"].first(MAX_ROWS).each do |item|
          lines << "  #{item['rank']}. #{item['title']} — #{truncate(item['reason'])}"
        end
        "#{lines.join("\n")}\n"
      end

      def render_observations(verdicts)
        lines = verdicts.map do |verdict|
          "  [#{verdict['status']}] #{verdict['observation_id'].to_s[0, 19]}… (#{verdict['code']})"
        end
        "Observations:\n#{lines.join("\n")}\n"
      end

      def render_workflow(receipt)
        lines = []
        lines << "Workflow: #{receipt['readiness']} (gate #{receipt['gate']}, policy #{receipt['policy_decision']})"
        lines << "Receipt: #{receipt['workflow_receipt_id']}"
        receipt["observations"].each do |entry|
          lines << "  [#{entry['binding']}] #{entry['observation_id'].to_s[0, 19]}… by #{entry['author']}"
        end
        lines << "Reason codes: #{Array(receipt['reason_codes']).join(', ')}"
        "#{lines.join("\n")}\n"
      end

      def render_repair_verify(result)
        lines = []
        lines << "Repair verify: #{result.overall_status} " \
                 "(target #{result.target_status}, gate #{result.gate})"
        lines << "New blocking findings: #{result.new_blocking_findings}"
        boundary = result.verification_boundary_changed
        lines << "Boundary changed: #{boundary.inspect}" if boundary && boundary != false
        lines << "Regressed: #{result.regressed}" if result.regressed
        "#{lines.join("\n")}\n"
      end

      def truncate(text)
        text = text.to_s
        text.length > 160 ? "#{text[0, 157]}..." : text
      end
      private_class_method :truncate
    end
  end
end
