# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module SchemaParser
      def self.parse(repository_root:)
        path = File.join(repository_root, "db/schema.rb")
        return {} unless File.file?(path)
        return {} if File.size(path) > Limits::MAX_FILE_BYTES rescue nil

        text = File.binread(path)
        return {} if text.bytesize > Limits::MAX_FILE_BYTES

        text.force_encoding(Encoding::UTF_8)
        return {} unless text.valid_encoding?

        tables = {}
        text.scan(/create_table\s+["']([^"']+)["']/) do |match|
          table = match[0].to_s.strip
          next if table.empty?
          next if tables.key?(table)

          break if tables.length >= Limits::MAX_SCHEMA_TABLES

          snippet = extract_table_snippet(text, table)
          tables[table] = snippet
        end
        tables
      rescue StandardError
        {}
      end

      def self.extract_table_snippet(text, table)
        pattern = /create_table\s+["']#{Regexp.escape(table)}["'].*?\n(.*?)end/m
        match = text.match(pattern)
        return { "columns" => [] } unless match

        block_text = match[1].to_s
        columns = []
        block_text.scan(/t\.\w+\s+["']([^"']+)["']/) do |col_match|
          break if columns.length >= Limits::MAX_COLUMNS_PER_TABLE

          columns << { "name" => col_match[0], "type" => "unknown" }
        end
        { "columns" => columns }
      end
      private_class_method :extract_table_snippet
    end
  end
end
