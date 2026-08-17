# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module Resolvers
      module PolicyResolver
        def self.for(repository_root:, kind:, path:, constant:)
          return [] unless %w[model controller].include?(kind)
          return [] if constant.nil? || constant.empty?

          base_name = constant.split("::").last.to_s
          snake = underscore(base_name)
          dir_parts = constant.split("::")[0...-1].map { |part| underscore(part) }
          relative_dir = dir_parts.empty? ? "" : "#{dir_parts.join('/')}/"
          repo_relative = "app/policies/#{relative_dir}#{snake}_policy.rb"
          full = File.join(repository_root, repo_relative)
          return [] unless safe_exists?(repository_root, full)

          [{ "path" => repo_relative, "relationship" => "policy", "confidence" => "conventional", "provenance" => "file_exists:#{repo_relative}" }]
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

        def self.safe_exists?(root, full)
          return false unless File.file?(full)

          real = File.realpath(full) rescue full
          real_root = File.realpath(root) rescue root
          real.start_with?(real_root)
        rescue StandardError
          false
        end
        private_class_method :safe_exists?
      end
    end
  end
end
