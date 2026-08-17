# frozen_string_literal: true

module RailVerdict
  module Reporters
    module GitHubAnnotations
      module_function

      def render(result, findings: nil)
        findings_list = findings || result.findings
        lines = []
        findings_list.sort_by { |finding| [finding["path"] || finding["location"]&.dig("path") || "", finding["start_line"] || finding["location"]&.dig("start_line") || 0, finding["id"] || ""] }.each do |finding|
          path = extract_path(finding)
          line = extract_line(finding)
          col = extract_column(finding)
          message = finding["message"] || finding[:message] || finding["id"] || ""
          rule_id = finding["rule_id"] || finding[:rule_id] || finding["id"] || "unknown"
          analyzer = finding["analyzer"] || finding[:analyzer] || "unknown"
          severity = finding["severity"] || finding[:severity] || "info"
          blocking = finding["blocking"]
          level = annotation_level(severity, blocking, result.gate)
          file_part = "file=#{escape_property(path)}"
          line_part = line ? ",line=#{line}" : ""
          col_part = col ? ",col=#{col}" : ""
          title = escape_data("#{analyzer}:#{rule_id}")
          msg = escape_data("#{message} [#{finding['state'] || finding[:state] || 'observed'}]")
          lines << "::#{level} #{file_part}#{line_part}#{col_part},title=#{title}::#{msg}"
        end
        lines.join("\n") + (lines.empty? ? "" : "\n")
      end

      def render_summary_markdown(result, findings: nil)
        findings_list = findings || result.findings
        header = "| File | Rule | Message | Severity | State | Blocking |\n| --- | --- | --- | --- | --- | --- |\n"
        rows = findings_list.sort_by { |finding| [finding["path"] || finding["location"]&.dig("path") || "", finding["id"] || ""] }.map do |finding|
          path = finding["path"] || finding["location"]&.dig("path") || finding[:path] || "unknown"
          rule = finding["rule_id"] || finding[:rule_id] || finding["id"] || ""
          msg = (finding["message"] || finding[:message] || "").to_s.gsub("|", "\\|").gsub("\n", " ")[0, 200]
          severity = finding["severity"] || finding[:severity] || ""
          state = finding["state"] || finding[:state] || ""
          blocking = finding["blocking"] ? "yes" : "no"
          "| #{path} | #{rule} | #{msg} | #{severity} | #{state} | #{blocking} |"
        end
        summary = "# RailVerdict #{result.gate} (#{result.policy_status})\n\n"
        summary += findings_list.empty? ? "No findings.\n" : header + rows.join("\n") + "\n"
        summary += "\nReasons:\n"
        result.decision_reasons.each do |reason|
          summary += "- #{reason.fetch('code')}: #{reason.fetch('message')}\n"
        end
        summary
      end

      def annotation_level(severity, blocking, gate)
        return "error" if blocking == true
        return "error" if gate == "FAIL"

        case severity.to_s
        when "critical", "high"
          "error"
        when "medium"
          "warning"
        when "low", "info"
          "notice"
        else
          "notice"
        end
      end
      private_class_method :annotation_level

      def extract_path(finding)
        loc = finding["location"] || finding[:location]
        return finding["path"] || finding[:path] || "unknown" if !loc.is_a?(Hash)

        loc["path"] || loc[:path] || finding["path"] || "unknown"
      end
      private_class_method :extract_path

      def extract_line(finding)
        loc = finding["location"] || finding[:location]
        return finding["start_line"] || finding[:start_line] if !loc.is_a?(Hash) || loc.nil?

        loc["start_line"] || loc[:start_line]
      end
      private_class_method :extract_line

      def extract_column(finding)
        loc = finding["location"] || finding[:location]
        return finding["start_column"] || finding[:start_column] if !loc.is_a?(Hash) || loc.nil?

        loc["start_column"] || loc[:start_column]
      end
      private_class_method :extract_column

      def escape_property(value)
        value.to_s.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A").gsub(":", "%3A").gsub(",", "%2C")
      end
      private_class_method :escape_property

      def escape_data(value)
        value.to_s.gsub("%", "%25").gsub("\r", "%0D").gsub("\n", "%0A")
      end
      private_class_method :escape_data
    end
  end
end
