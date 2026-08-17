# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module Resolvers
      module ViewResolver
        ALLOWED_EXTENSIONS = %w[.html.erb .turbo_stream.erb .json.jbuilder .html.haml .erb .jbuilder].freeze

        def self.for(repository_root:, kind:, path:, constant:)
          return [] unless kind == "controller"
          return [] if constant.nil? || constant.empty?

          base = constant.delete_suffix("Controller")
          parts = base.split("::").map { |part| underscore(part) }
          view_dir = File.join(repository_root, "app/views", *parts)
          return [] unless File.directory?(view_dir)

          real = File.realpath(view_dir) rescue view_dir
          real_root = File.realpath(repository_root) rescue repository_root
          return [] unless real.start_with?(real_root)

          entries = Dir.children(view_dir).sort.first(Limits::MAX_RELATED)
          entries.filter_map do |name|
            full = File.join(view_dir, name)
            next unless File.file?(full)
            next unless ALLOWED_EXTENSIONS.any? { |ext| name.end_with?(ext) }

            repo_relative = "app/views/#{parts.join('/')}/#{name}"
            { "path" => repo_relative, "relationship" => "view", "confidence" => "conventional", "provenance" => "dir_exists:app/views/#{parts.join('/')}" }
          end
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
