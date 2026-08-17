# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module Resolvers
      module RouteResolver
        def self.for(repository_root:, kind:, constant:)
          routes_path = File.join(repository_root, "config/routes.rb")
          return [] unless File.file?(routes_path)

          real = File.realpath(routes_path) rescue routes_path
          real_root = File.realpath(repository_root) rescue repository_root
          return [] unless real.start_with?(real_root)

          base = [{ "path" => "config/routes.rb", "relationship" => "routes", "confidence" => "exact", "provenance" => "file_exists:config/routes.rb" }]

          return base unless kind == "controller" && constant

          controller_key = underscore(constant.delete_suffix("Controller"))
          scan = RouteScanner.scan(repository_root: repository_root)
          matching = scan[:declarations].select { |decl| decl["controller"] == controller_key || decl["controller"] == controller_key.split("/").last }

          matching.first(Limits::MAX_RELATED).map do |decl|
            { "path" => "config/routes.rb", "relationship" => "route_declaration:#{decl['controller']}", "confidence" => "exact", "provenance" => "literal:#{decl['declaration'][0, 120]}" }
          end.then { |extra| (base + extra).first(Limits::MAX_RELATED) }
        rescue StandardError
          []
        end

        def self.underscore(camel)
          word = camel.to_s.dup
          word.gsub!(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
          word.gsub!(/([a-z\d])([A-Z])/, '\1_\2')
          word.downcase
        end
        private_class_method :underscore
      end
    end
  end
end
