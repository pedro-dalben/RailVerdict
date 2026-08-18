# frozen_string_literal: true

module RailVerdict
  module Repair
    module Verifier
      Result = Struct.new(:target_status, :gate, :completion_status, :new_blocking_findings, :verification_boundary_changed, :regressed, :overall_status, keyword_init: true) do
        def overall_status
          self[:overall_status] || derive_overall
        end

        private

        def derive_overall
          return "incomplete" if completion_status == "incomplete" || target_status == "incomplete"
          return "boundary_changed" if verification_boundary_changed && verification_boundary_changed != false
          return "successful" if target_status == "fixed" && %w[PASS WARN].include?(gate) && !regressed

          "unsuccessful"
        end
      end

      def self.verify(packet:, new_outcome:)
        packet_hash = packet.is_a?(Packet) ? packet.to_h : packet
        fingerprint = packet_hash.dig("target", "finding", "fingerprint")
        new_findings = new_outcome.findings || []
        new_result = new_outcome.result

        if new_result&.incomplete?
          return Result.new(
            target_status: "incomplete",
            gate: new_result.gate,
            completion_status: new_result.completion_status,
            new_blocking_findings: new_result.findings.count { |f| f["blocking"] },
            verification_boundary_changed: boundary_changed?(packet_hash, new_outcome),
            regressed: false
          )
        end

        target_still = new_findings.find { |f| f.fingerprint == fingerprint }
        target_status = if target_still.nil?
                          changed = new_findings.find { |f| f.location["path"] == packet_hash.dig("target", "finding", "location", "path") && f.analyzer == packet_hash.dig("target", "finding", "analyzer") && f.rule_id == packet_hash.dig("target", "finding", "rule_id") }
                          if changed
                            changed.message == packet_hash.dig("target", "finding", "message") ? "moved" : "changed"
                          else
                            "fixed"
                          end
                        else
                          "still_present"
                        end

        boundary = boundary_changed?(packet_hash, new_outcome)
        blocking_now = new_result.findings.count { |f| f["blocking"] }
        old_blocking = packet_hash.dig("verification", "comparison_counts") || {}
        regressed = blocking_now > 0 && target_status == "fixed"

        res = Result.new(
          target_status: target_status,
          gate: new_result.gate,
          completion_status: new_result.completion_status,
          new_blocking_findings: blocking_now,
          verification_boundary_changed: boundary,
          regressed: regressed
        )
        res[:overall_status] = res.overall_status
        res
      end

      def self.boundary_changed?(packet_hash, new_outcome)
        old = packet_hash["boundary"] || {}
        root = new_outcome.context&.repository_root || Dir.pwd
        config = new_outcome.configuration
        current = Boundary.snapshot(repository_root: root, configuration: config, outcome: new_outcome)
        changed = {}
        changed["config"] = true if old["configuration_digest"] && current["configuration_digest"] && old["configuration_digest"] != current["configuration_digest"]
        changed["baseline"] = true if old["baseline_digest"] != current["baseline_digest"]
        changed["waivers"] = true if old["waivers_digest"] != current["waivers_digest"]
        changed["base"] = true if old["base_revision"] != current["base_revision"] && !(old["base_revision"].nil? && current["base_revision"].nil?)
        changed["source"] = true if old["source_revision"] != current["source_revision"] && !(old["source_revision"].nil? && current["source_revision"].nil?)
        changed.empty? ? false : changed
      end
      private_class_method :boundary_changed?
    end
  end
end
