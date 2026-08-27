# frozen_string_literal: true

require "pathname"
require_relative "rails_context/classifier"
require_relative "rails_context/resolvers/test_candidates"

module RailVerdict
  module TestSelection
    Result = Struct.new(:scope, :selected_files, :fallback_reason, :changed_files_count, keyword_init: true)

    SAFE_FALLBACK_PATTERNS = [
      %r{\Aspec/(spec_helper|rails_helper)\.rb\z},
      %r{\Aspec/support/},
      %r{\Atest/test_helper\.rb\z},
      %r{\A(Gemfile|Gemfile\.lock|\.gemspec|.*\.gemspec)\z},
      %r{\Aconfig/(application|environment|boot|routes)\.rb\z},
      %r{\Aconfig/(environments|initializers)/},
      %r{\Adb/(schema\.rb|structure\.sql|migrate/)},
      %r{\Aapp/models/application_record\.rb\z},
      %r{\Aapp/controllers/application_controller\.rb\z},
      %r{\Aapp/jobs/application_job\.rb\z},
      %r{\Aapp/mailers/application_mailer\.rb\z},
      %r{\Aapp/channels/application_cable/}
    ].freeze

    NON_CODE_EXTENSIONS = %w[.md .markdown .txt .gitignore .rdoc .license].freeze
    NON_CODE_DIRS = %w[docs/ public/ log/ tmp/ .github/ .agent/ .agents/ .cursor/ .vscode/ .planning/ .commandcode/].freeze
    NON_CODE_PATTERNS = [
      %r{\A\.railverdict.*},
      %r{\A\.rubocop.*},
      %r{\A\.eslint.*},
      %r{\A\.prettier.*},
      %r{\A\.editorconfig\z},
      %r{\A\.gitattributes\z},
      %r{\A\.dockerignore\z},
      %r{\A\.windsurfrules\z},
      %r{\A\.cursorrules\z},
      %r{\AAGENTS\.md\z},
      %r{\ACLOUDE\.md\z},
      %r{\AGEMINI\.md\z},
      %r{\APROJECT_RULES\.md\z},
      %r{\Aproject\.rules\z}
    ].freeze

    module_function

    def resolve(repository_root:, git_context: nil, changed_files: nil, framework: :rspec)
      raw_files = if git_context.respond_to?(:changed_files)
                    git_context.changed_files
                  elsif changed_files
                    changed_files
                  else
                    []
                  end

      paths = extract_paths(raw_files)
      if paths.empty?
        return Result.new(
          scope: "full",
          selected_files: [],
          fallback_reason: "empty_or_unresolvable_changed_scope",
          changed_files_count: 0
        )
      end

      # 1. Check for safe fallback infrastructure changes
      paths.each do |path|
        if SAFE_FALLBACK_PATTERNS.any? { |pattern| path.match?(pattern) }
          return Result.new(
            scope: "full",
            selected_files: [],
            fallback_reason: "shared_infrastructure_changed:#{path}",
            changed_files_count: paths.length
          )
        end
      end

      # 2. Iterate through files and resolve candidate specs
      selected = []
      code_files_count = 0

      paths.each do |path|
        next if non_code_path?(path)

        code_files_count += 1

        # Direct spec / test edits
        if path.start_with?("spec/") && path.end_with?("_spec.rb")
          if framework == :rspec || framework == :all
            selected << path if safe_file_exists?(repository_root, path)
          end
          next
        elsif path.start_with?("test/") && path.end_with?("_test.rb")
          if framework == :minitest || framework == :all
            selected << path if safe_file_exists?(repository_root, path)
          end
          next
        end

        # Code in app/ or lib/
        kind = RailsContext::Classifier.classify(path)
        if %w[model controller job mailer helper service policy component view lib].include?(kind)
          candidates = RailsContext::Resolvers::TestCandidates.for(
            repository_root: repository_root,
            kind: kind,
            path: path
          )
          matching = candidates.map { |c| c["path"] }
          matching = if framework == :rspec
                       matching.select { |p| p.start_with?("spec/") }
                     elsif framework == :minitest
                       matching.select { |p| p.start_with?("test/") }
                     else
                       matching
                     end

          if matching.empty?
            # Unmapped code change: fall back to full suite safely
            return Result.new(
              scope: "full",
              selected_files: [],
              fallback_reason: "unmapped_source_change:#{path}",
              changed_files_count: paths.length
            )
          end

          selected.concat(matching)
        else
          # Any other unclassified code file (e.g. scripts, bins, unrecognized app dirs)
          return Result.new(
            scope: "full",
            selected_files: [],
            fallback_reason: "unrecognized_source_file:#{path}",
            changed_files_count: paths.length
          )
        end
      end

      if code_files_count > 0 && selected.empty?
        return Result.new(
          scope: "full",
          selected_files: [],
          fallback_reason: "no_candidate_tests_found",
          changed_files_count: paths.length
        )
      end

      Result.new(
        scope: "targeted",
        selected_files: selected.uniq.sort,
        fallback_reason: nil,
        changed_files_count: paths.length
      )
    end

    def extract_paths(raw_files)
      Array(raw_files).map do |file|
        if file.respond_to?(:path)
          file.path.to_s
        elsif file.is_a?(Hash)
          (file["path"] || file[:path]).to_s
        else
          file.to_s
        end
      end.map { |p| p.delete_prefix("./").delete_prefix("/").strip }.reject(&:empty?).uniq
    end
    private_class_method :extract_paths

    def non_code_path?(path)
      return true if NON_CODE_DIRS.any? { |dir| path.start_with?(dir) }
      return true if NON_CODE_EXTENSIONS.any? { |ext| path.end_with?(ext) }
      return true if NON_CODE_PATTERNS.any? { |pattern| pattern.match?(path) }

      false
    end
    private_class_method :non_code_path?

    def safe_file_exists?(root, relative_path)
      full = File.join(root, relative_path)
      File.file?(full)
    rescue StandardError
      false
    end
    private_class_method :safe_file_exists?
  end
end
