# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module Resolvers
      module AssociationExtractor
        MACROS = %w[belongs_to has_one has_many has_and_belongs_to_many].freeze

        def self.extract(repository_root:, path:)
          full = File.join(repository_root, path)
          return [] unless File.file?(full)
          return [] if File.size(full) > Limits::MAX_FILE_BYTES rescue nil

          text = File.binread(full)
          return [] if text.bytesize > Limits::MAX_FILE_BYTES

          text.force_encoding(Encoding::UTF_8)
          return [] unless text.valid_encoding?
          return [] if text.include?("\x00")

          results = []
          text.each_line do |line|
            stripped = line.strip
            next if stripped.start_with?("#")

            MACROS.each do |macro|
              match = stripped.match(/\A#{Regexp.escape(macro)}\s+[:"]?([a-z_][a-z0-9_]*)["']?/)
              next unless match

              after = stripped[match[0].length..].to_s.strip
              next if after.start_with?("->") || after.include?("proc") || after.include?("lambda")

              name = match[1].to_s
              next if name.empty?

              results << { "name" => name, "macro" => macro, "confidence" => "exact", "provenance" => "literal:#{macro} :#{name}" }
              break if results.length >= Limits::MAX_ASSOCIATIONS
            end
            break if results.length >= Limits::MAX_ASSOCIATIONS
          end
          results
        rescue StandardError
          []
        end
      end
    end
  end
end
