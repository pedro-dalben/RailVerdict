# frozen_string_literal: true

module RailVerdict
  module Git
    module DiffParser
      module_function

      def parse_name_status_nul(raw)
        return [] if raw.nil? || raw.empty?

        parts = raw.split("\0")
        parts.pop if parts.last == ""
        files = []
        index = 0
        while index < parts.length
          entry = parts[index]
          break if entry.nil? || entry.empty?

          status_char = entry[0]
          case status_char
          when "R", "C"
            old_path = parts[index + 1]
            new_path = parts[index + 2]
            if old_path.nil? || new_path.nil?
              raise Git::Error, "malformed git name-status output (rename requires two paths)"
            end
            score = entry[1..].to_i
            files << ChangedFile.new(status: status_char == "R" ? :renamed : :copied, path: normalize_path(new_path), old_path: normalize_path(old_path), new_path: normalize_path(new_path), score: score, binary: false)
            index += 3
          when "A"
            path = parts[index + 1]
            raise Git::Error, "malformed git name-status output (added requires path)" if path.nil?

            files << ChangedFile.new(status: :added, path: normalize_path(path), old_path: nil, new_path: normalize_path(path), score: nil, binary: false)
            index += 2
          when "D"
            path = parts[index + 1]
            raise Git::Error, "malformed git name-status output (deleted requires path)" if path.nil?

            files << ChangedFile.new(status: :deleted, path: nil, old_path: normalize_path(path), new_path: nil, score: nil, binary: false)
            index += 2
          when "M", "T"
            path = parts[index + 1]
            raise Git::Error, "malformed git name-status output (modified requires path)" if path.nil?

            mapped = status_char == "T" ? :typechange : :modified
            files << ChangedFile.new(status: mapped, path: normalize_path(path), old_path: normalize_path(path), new_path: normalize_path(path), score: nil, binary: false)
            index += 2
          else
            raise Git::Error, "unexpected git name-status entry: #{entry.inspect}"
          end
        end
        files.sort_by { |file| (file.path || file.old_path || "").to_s }
      end

      def parse_numstat_nul(raw)
        return {} if raw.nil? || raw.empty?

        parts = raw.split("\0")
        parts.pop if parts.last == ""
        result = {}
        parts.each do |entry|
          next if entry.empty?

          fields = entry.split("\t")
          next unless fields.length == 3

          added, deleted, path = fields
          binary = added == "-" || deleted == "-"
          result[normalize_path(path)] = { added: binary ? nil : added.to_i, deleted: binary ? nil : deleted.to_i, binary: binary }
        end
        result
      end

      def parse_numstat_rename_nul(raw)
        return {} if raw.nil? || raw.empty?

        parts = raw.split("\0")
        parts.pop if parts.last == ""
        result = {}
        index = 0
        while index < parts.length
          entry = parts[index]
          index += 1
          next if entry.empty?

          fields = entry.split("\t")
          next unless fields.length >= 2

          added, deleted = fields[0], fields[1]
          binary = added == "-" || deleted == "-"
          if fields.length >= 3
            path = fields[2]
          else
            old_path = parts[index]
            new_path = parts[index + 1]
            break if old_path.nil? || new_path.nil?

            path = new_path
            index += 2
          end
          key = normalize_path(path)
          result[key] = { added: binary ? nil : added.to_i, deleted: binary ? nil : deleted.to_i, binary: binary }
        end
        result
      end

      def parse_changed_lines_unified(raw, changed_paths)
        return {} if raw.nil? || raw.empty?

        return {} if changed_paths.nil? || changed_paths.empty?

        binary_set = Set.new
        changed_paths.each do |file|
          binary_set.add(file[:path]) if file[:binary]
          binary_set.add(file[:new_path]) if file[:binary] && file[:new_path]
        end

        segments = split_unified_by_nul(raw)
        line_set = {}
        segments.each do |segment|
          path, diff_text = segment
          normalized = normalize_path(path.to_s)
          next if binary_set.include?(normalized)
          next if diff_text.nil? || diff_text.empty?

          lines = parse_unified_hunks(diff_text)
          line_set[normalized] = lines.sort.freeze unless lines.empty?
        end
        line_set
      end

      def split_unified_by_nul(raw)
        raw_text = raw.dup.force_encoding(Encoding::UTF_8).scrub("?")
        if raw_text.include?("\0")
          parts = raw_text.split("\0")
          parts.pop if parts.last == ""
          segments = []
          parts.each_slice(2) do |path, diff_text|
            next if path.nil?

            segments << [path, diff_text || ""]
          end
          segments
        else
          split_unified_without_nul(raw_text)
        end
      end

      def split_unified_without_nul(raw_text)
        segments = []
        current_path = nil
        current_lines = []
        raw_text.each_line do |line|
          if line.start_with?("diff --git ")
            if current_path
              segments << [current_path, current_lines.join]
            end
            match = line.match(%r{\Adiff --git a/.+ b/(.+)\n?\z})
            current_path = match ? match[1].strip : "unknown"
            current_lines = []
          elsif current_path
            current_lines << line
          end
        end
        segments << [current_path, current_lines.join] if current_path
        segments
      end
      private_class_method :split_unified_without_nul

      def parse_unified_hunks(diff_text)
        lines = []
        new_line = nil
        diff_text.each_line do |raw_line|
          if raw_line.start_with?("@@ ")
            match = raw_line.match(/\A@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/)
            new_line = match ? match[1].to_i : nil
            next
          end
          next if new_line.nil?
          next if raw_line.start_with?("diff --git") || raw_line.start_with?("index ") || raw_line.start_with?("--- ") || raw_line.start_with?("+++ ")

          if raw_line.start_with?("+")
            next if raw_line.start_with?("+++ ")

            lines << new_line
            new_line += 1
          elsif raw_line.start_with?("-")
            next
          elsif raw_line.start_with?(" ") || raw_line.start_with?("\\")
            new_line += 1 if raw_line.start_with?(" ")
          elsif raw_line.strip.empty?
            next
          else
            next
          end
        end
        lines
      end
      private_class_method :parse_unified_hunks

      def normalize_path(path)
        raw = path.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").strip
        raw = raw.delete_prefix("./")
        raw = raw.delete_prefix("/")
        raw = raw.unicode_normalize(:nfc) if raw.respond_to?(:unicode_normalize)
        raw
      end
      private_class_method :normalize_path
    end
  end
end
