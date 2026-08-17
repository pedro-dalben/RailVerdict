# frozen_string_literal: true

module RailVerdict
  module Coverage
    module ChangedLineEvaluator
      module_function

      def evaluate(coverage_document:, line_set:)
        raise ArgumentError, "coverage_document must be a Hash" unless coverage_document.is_a?(Hash)
        raise ArgumentError, "line_set must be a Hash" unless line_set.is_a?(Hash)

        files = coverage_document["files"]
        raise ArgumentError, "coverage document has no files array" unless files.is_a?(Array)

        coverage_map = {}
        files.each do |file|
          filename = file["filename"]
          coverage = file.dig("coverage", "lines")
          next unless filename.is_a?(String) && coverage.is_a?(Array)

          coverage_map[filename] = coverage
        end

        executable = 0
        covered = 0
        missing = []

        line_set.each do |path, lines|
          raise ArgumentError, "line_set path must be a string" unless path.is_a?(String)
          raise ArgumentError, "line_set lines must be an array" unless lines.is_a?(Array)

          coverage = coverage_map[path]
          lines.each do |line_number|
            raise ArgumentError, "line number must be an integer >= 1" unless line_number.is_a?(Integer) && line_number >= 1

            if coverage.nil? || line_number > coverage.length
              executable += 1
              missing << [path, line_number]
              next
            end

            hit = coverage[line_number - 1]
            if hit.nil?
              next
            end

            executable += 1
            if hit.to_i > 0
              covered += 1
            else
              missing << [path, line_number]
            end
          end
        end

        missing = missing.sort

        percent = executable == 0 ? 100.0 : ((covered.to_f / executable) * 100).round(2)

        {
          "covered_lines" => covered,
          "executable_lines" => executable,
          "missing_lines" => missing,
          "percent" => percent,
          "paths" => line_set.keys.sort
        }.freeze
      end
    end
  end
end
