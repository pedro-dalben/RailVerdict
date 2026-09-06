# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module Resolvers
      module TestCandidates
        def self.for(repository_root:, kind:, path:)
          basename = File.basename(path, ".*")
          dir = File.dirname(path)
          candidates = []

          case kind
          when "model"
            relative = dir.delete_prefix("app/models").delete_prefix("/")
            candidates << candidate_path(repository_root, "test", "models", relative, basename)
            candidates << candidate_path(repository_root, "spec", "models", relative, basename)
          when "controller"
            clean = basename.delete_suffix("_controller")
            relative = dir.delete_prefix("app/controllers").delete_prefix("/")
            candidates << candidate_path(repository_root, "test", "controllers", relative, basename)
            candidates << candidate_path(repository_root, "spec", "requests", relative, clean)
            candidates << candidate_path(repository_root, "spec", "controllers", relative, basename)
            candidates << candidate_path(repository_root, "spec", "requests", relative, "#{clean}_spec")
          when "job"
            relative = dir.delete_prefix("app/jobs").delete_prefix("/")
            candidates << candidate_path(repository_root, "test", "jobs", relative, basename)
            candidates << candidate_path(repository_root, "spec", "jobs", relative, basename)
          when "mailer"
            relative = dir.delete_prefix("app/mailers").delete_prefix("/")
            candidates << candidate_path(repository_root, "test", "mailers", relative, basename)
            candidates << candidate_path(repository_root, "spec", "mailers", relative, basename)
          when "helper"
            relative = dir.delete_prefix("app/helpers").delete_prefix("/")
            candidates << candidate_path(repository_root, "test", "helpers", relative, basename)
            candidates << candidate_path(repository_root, "spec", "helpers", relative, basename)
          when "service"
            relative = dir.delete_prefix("app/services").delete_prefix("/")
            candidates << candidate_path(repository_root, "test", "services", relative, basename)
            candidates << candidate_path(repository_root, "spec", "services", relative, basename)
          when "policy"
            clean = basename.delete_suffix("_policy")
            relative = dir.delete_prefix("app/policies").delete_prefix("/")
            candidates << candidate_path(repository_root, "test", "policies", relative, basename)
            candidates << candidate_path(repository_root, "spec", "policies", relative, basename)
            candidates << candidate_path(repository_root, "spec", "policies", relative, clean)
          when "component"
            clean = basename.delete_suffix("_component")
            relative = dir.delete_prefix("app/components").delete_prefix("/")
            candidates << candidate_path(repository_root, "test", "components", relative, basename)
            candidates << candidate_path(repository_root, "spec", "components", relative, basename)
            candidates << candidate_path(repository_root, "spec", "components", relative, clean)
          when "view"
            relative = dir.delete_prefix("app/views").delete_prefix("/")
            controller_dir = relative.split("/").first
            candidates << candidate_path(repository_root, "spec", "views", relative, basename)
            candidates << candidate_path(repository_root, "spec", "system", controller_dir || "", "#{controller_dir}_spec") if controller_dir
            candidates << candidate_path(repository_root, "spec", "requests", controller_dir || "", "#{controller_dir}_spec") if controller_dir
          when "lib"
            relative = dir.delete_prefix("lib").delete_prefix("/")
            candidates << candidate_path(repository_root, "spec", "lib", relative, basename)
            candidates << candidate_path(repository_root, "spec", "", relative, basename)
            candidates << candidate_path(repository_root, "test", "lib", relative, basename)
            candidates << candidate_path(repository_root, "test", "", relative, basename)
          when "spec"
            if path.end_with?("_spec.rb") && safe_exists?(repository_root, File.join(repository_root, path))
              candidates << { path: path, exists: true }
            end
          when "test"
            if path.end_with?("_test.rb") && safe_exists?(repository_root, File.join(repository_root, path))
              candidates << { path: path, exists: true }
            end
          else
            return []
          end

          candidates.compact.select { |entry| entry[:exists] }.map do |entry|
            { "path" => entry[:path], "relationship" => "related_test", "confidence" => "conventional", "provenance" => "file_exists:#{entry[:path]}" }
          end
        end

        def self.candidate_path(root, framework, kind_dir, relative, basename)
          rel = relative.empty? ? "" : "#{relative}/"
          clean_base = basename.delete_suffix("_spec").delete_suffix("_test")
          filename = framework == "test" ? "#{clean_base}_test.rb" : "#{clean_base}_spec.rb"
          repo_relative = "#{framework}/#{kind_dir}/#{rel}#{filename}".gsub(%r{//+}, "/").delete_prefix("/")
          full = File.join(root, repo_relative)
          exists = safe_exists?(root, full)
          return nil unless exists

          { path: repo_relative, exists: true }
        rescue StandardError
          nil
        end
        private_class_method :candidate_path

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
