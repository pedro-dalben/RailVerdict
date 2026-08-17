# frozen_string_literal: true

module RailVerdict
  module Intelligence
    module SourceReader
      MAX_FILES = 3
      MAX_LINES_PER_FILE = 80
      MAX_TOTAL_BYTES = 32 * 1024
      MAX_FILE_BYTES = 1_048_576

      def self.read_snippet(repository_root:, path:, target_line: nil)
        root = File.realpath(repository_root.to_s)
        rel = path.to_s.delete_prefix("./").delete_prefix("/")
        full = File.join(root, rel)
        real = File.realpath(full) rescue nil
        return nil unless real && real.start_with?(root + File::SEPARATOR) || real == root
        return nil unless File.file?(real)
        return nil if File.size(real) > MAX_FILE_BYTES rescue false

        bytes = File.binread(real) rescue nil
        return nil unless bytes

        text = bytes.dup.force_encoding(Encoding::UTF_8)
        text = text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?") unless text.valid_encoding?
        text = text.unicode_normalize(:nfc) if text.respond_to?(:unicode_normalize)

        lines = text.lines
        return nil if lines.empty?

        if target_line && target_line >= 1
          half = MAX_LINES_PER_FILE / 2
          start_idx = [target_line - half - 1, 0].max
          end_idx = [start_idx + MAX_LINES_PER_FILE - 1, lines.length - 1].min
          start_idx = [end_idx - MAX_LINES_PER_FILE + 1, 0].max
          slice = lines[start_idx..end_idx] || []
          content = slice.join
        else
          content = lines.first(MAX_LINES_PER_FILE).join
        end

        content = content.byteslice(0, MAX_TOTAL_BYTES) || ""
        content = content.scrub("?")
        { path: rel, content: content, truncated: bytes.bytesize > content.bytesize }
      rescue StandardError
        nil
      end
    end
  end
end
