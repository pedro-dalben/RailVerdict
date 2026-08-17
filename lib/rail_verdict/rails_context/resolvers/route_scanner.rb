# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module Resolvers
      module RouteScanner
        def self.scan(repository_root:)
          path = File.join(repository_root, "config/routes.rb")
          return { declarations: [], unresolved: false } unless File.file?(path)
          return { declarations: [], unresolved: false } if File.size(path) > Limits::ROUTES_MAX_BYTES rescue nil

          text = File.binread(path)
          return { declarations: [], unresolved: false } if text.bytesize > Limits::ROUTES_MAX_BYTES

          text.force_encoding(Encoding::UTF_8)
          return { declarations: [], unresolved: false } unless text.valid_encoding?
          return { declarations: [], unresolved: true } if text.include?("\x00")

          declarations = []
          unresolved = false

          text.each_line do |line|
            stripped = line.strip
            next if stripped.empty? || stripped.start_with?("#")

            if stripped.match?(/\b(draw|mount|concern|constraints)\b/)
              unresolved = true
              next
            end

            if (match = stripped.match(/\bresources\s*:\s*(\w+)/))
              declarations << { "controller" => match[1], "declaration" => stripped, "confidence" => "exact" }
              next
            end
            if (match = stripped.match(/\bresource\s*:\s*(\w+)/))
              declarations << { "controller" => match[1], "declaration" => stripped, "confidence" => "exact" }
              next
            end
            if (match = stripped.match(/\b(?:get|post|put|patch|delete)\s+['\"][^'\"]*['\"]\s*,\s*to:\s*['\"](\w+)#/))
              declarations << { "controller" => match[1], "declaration" => stripped, "confidence" => "exact" }
              next
            end
            if stripped.match?(/\bresources\b/) && stripped.include?("do")
              unresolved = true
            end
          end

          { declarations: declarations.first(Limits::MAX_RELATED), unresolved: unresolved }
        rescue StandardError
          { declarations: [], unresolved: false }
        end
      end
    end
  end
end
