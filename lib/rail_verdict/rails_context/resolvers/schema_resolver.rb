# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module Resolvers
      module SchemaResolver
        def self.for(repository_root:, kind:, constant:, path:)
          return [] unless kind == "model"
          return [] if constant.nil? || constant.empty?

          table = inferred_table(constant)
          custom = custom_table_name(repository_root, path)
          if custom
            if custom[:literal]
              return [{ "path" => "db/schema.rb", "relationship" => "schema_table:#{custom[:table]}", "confidence" => "exact", "provenance" => "literal:self.table_name=\"#{custom[:table]}\"" }]
            else
              return [{ "path" => "db/schema.rb", "relationship" => "schema_table", "confidence" => "unresolved", "provenance" => "dynamic_table_name" }]
            end
          end

          schema = SchemaParser.parse(repository_root: repository_root)
          has_structure_sql = File.file?(File.join(repository_root, "db/structure.sql"))

          if schema.key?(table)
            return [{ "path" => "db/schema.rb", "relationship" => "schema_table:#{table}", "confidence" => "conventional", "provenance" => "schema_table:#{table}" }]
          end

          if has_structure_sql
            return [{ "path" => "db/structure.sql", "relationship" => "schema_table", "confidence" => "unresolved", "provenance" => "structure_sql_not_parsed" }]
          end

          if table
            return [{ "path" => "db/schema.rb", "relationship" => "schema_table:#{table}", "confidence" => "inferred", "provenance" => "inferred_table:#{table}" }]
          end

          []
        rescue StandardError
          []
        end

        def self.inferred_table(constant)
          base = constant.split("::").last.to_s
          snake = underscore(base)
          naive_pluralize(snake)
        end
        private_class_method :inferred_table

        def self.custom_table_name(root, path)
          full = File.join(root, path)
          return nil unless File.file?(full)
          return nil if File.size(full) > Limits::MAX_FILE_BYTES rescue nil

          text = File.binread(full)
          return nil if text.bytesize > Limits::MAX_FILE_BYTES

          text.force_encoding(Encoding::UTF_8)
          return nil unless text.valid_encoding?
          return nil if text.include?("\x00")

          literal = text.match(/self\.table_name\s*=\s*["']([^"']+)["']/)
          return { literal: true, table: literal[1] } if literal

          dynamic = text.match(/self\.table_name\s*=/)
          return { literal: false, table: nil } if dynamic

          nil
        rescue StandardError
          nil
        end
        private_class_method :custom_table_name

        def self.underscore(camel)
          word = camel.to_s.dup
          word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
          word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
          word.downcase
        end
        private_class_method :underscore

        def self.naive_pluralize(word)
          return "#{word}s" if word.empty?
          return "#{word}es" if word.end_with?("s", "x", "z", "ch", "sh")

          "#{word}s"
        end
        private_class_method :naive_pluralize
      end
    end
  end
end
