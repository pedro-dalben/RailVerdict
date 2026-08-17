# frozen_string_literal: true

require "json"

module RailVerdict
  module Reporters
    module Sarif
      SEVERITY_LEVEL = {
        "critical" => "error",
        "high" => "error",
        "medium" => "warning",
        "low" => "note",
        "info" => "note"
      }.freeze

      module_function

      def render(result, findings: nil)
        all_findings = findings || result.findings
        rules = dedup_rules(all_findings)
        results = all_findings.map { |finding| finding_to_result(finding) }.sort_by { |entry| [entry["ruleId"].to_s, entry.dig("locations", 0, "physicalLocation", "artifactLocation", "uri").to_s, entry.dig("locations", 0, "physicalLocation", "region", "startLine").to_i] }

        {
          "version" => "2.1.0",
          "$schema" => "https://json.schemastore.org/sarif-2.1.0.json",
          "runs" => [
            {
              "tool" => {
                "driver" => {
                  "name" => "RailVerdict",
                  "version" => RailVerdict::VERSION,
                  "informationUri" => "https://railverdict.dev",
                  "rules" => rules
                }
              },
              "results" => results,
              "invocations" => [
                {
                  "executionSuccessful" => result.completion_status == "complete",
                  "toolExecutionNotifications" => result.decision_reasons.map { |reason| { "message" => { "text" => reason.fetch("message") }, "level" => "note", "descriptor" => { "id" => reason.fetch("code") } } }
                }
              ]
            }
          ]
        }
      end

      def render_json(result, findings: nil)
        JSON.generate(render(result, findings: findings)) + "\n"
      end

      def finding_to_result(finding)
        severity = finding["severity"] || finding[:severity] || "info"
        level = SEVERITY_LEVEL.fetch(severity.to_s, "note")
        fingerprint = finding["fingerprint"] || finding[:fingerprint]
        path = extract_path(finding)
        start_line = extract_start_line(finding)
        message = finding["message"] || finding[:message] || finding["id"] || finding[:id] || ""

        location = {
          "physicalLocation" => {
            "artifactLocation" => { "uri" => uri_encode(path) }
          }
        }
        if start_line
          location["physicalLocation"]["region"] = { "startLine" => start_line.to_i }
          col = extract_start_column(finding)
          location["physicalLocation"]["region"]["startColumn"] = col.to_i if col
        end

        result = {
          "ruleId" => finding["rule_id"] || finding[:rule_id] || finding["id"] || finding[:id] || "unknown",
          "level" => level,
          "message" => { "text" => message.to_s },
          "locations" => [location]
        }
        if fingerprint
          result["partialFingerprints"] = { "primaryLocationLineHash" => fingerprint.to_s }
          result["fingerprints"] = { "primaryLocationLineHash" => fingerprint.to_s }
        end
        result["properties"] = { "severity" => severity.to_s, "state" => (finding["state"] || finding[:state] || "observed").to_s } if finding["state"] || finding[:state]
        result
      end
      private_class_method :finding_to_result

      def extract_path(finding)
        loc = finding["location"] || finding[:location]
        return finding["path"] || finding[:path] || "unknown" unless loc.is_a?(Hash)

        loc["path"] || loc[:path] || finding["path"] || "unknown"
      end
      private_class_method :extract_path

      def extract_start_line(finding)
        loc = finding["location"] || finding[:location]
        return nil unless loc.is_a?(Hash)

        loc["start_line"] || loc[:start_line]
      end
      private_class_method :extract_start_line

      def extract_start_column(finding)
        loc = finding["location"] || finding[:location]
        return nil unless loc.is_a?(Hash)

        loc["start_column"] || loc[:start_column]
      end
      private_class_method :extract_start_column

      def dedup_rules(findings)
        seen = {}
        findings.each do |finding|
          rule_id = finding["rule_id"] || finding[:rule_id] || finding["id"] || "unknown"
          analyzer = finding["analyzer"] || finding[:analyzer] || "unknown"
          key = "#{analyzer}:#{rule_id}"
          next if seen.key?(key)

          seen[key] = {
            "id" => rule_id.to_s,
            "name" => rule_id.to_s,
            "shortDescription" => { "text" => "#{analyzer}/#{rule_id}" },
            "fullDescription" => { "text" => "Analyzer #{analyzer} rule #{rule_id}" },
            "properties" => { "analyzer" => analyzer.to_s }
          }
        end
        seen.values.sort_by { |rule| rule["id"].to_s }
      end
      private_class_method :dedup_rules

      def uri_encode(path)
        str = path.to_s.dup.force_encoding(Encoding::UTF_8).scrub("?")
        str = str.gsub("\\", "/")
        str.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")
      end
      private_class_method :uri_encode
    end
  end
end
