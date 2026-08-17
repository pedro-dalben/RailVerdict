# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module Detector
      def self.detect(repository_root:)
        root = File.realpath(repository_root.to_s) rescue repository_root.to_s
        lockfile = read_text(File.join(root, "Gemfile.lock"), Limits::MAX_FILE_BYTES)
        ruby_version = lockfile ? lockfile[RunContext::GEMFILE_LOCK_RUBY, 1] : nil
        rails_version = lockfile ? lockfile[RunContext::GEMFILE_LOCK_RAILS, 1] : nil
        {
          "ruby_version" => ruby_version,
          "target_ruby_version" => ruby_version,
          "rails_version" => rails_version,
          "test_framework" => detect_test_framework(root, lockfile),
          "database_adapter" => detect_database_adapter(root, lockfile),
          "dependencies" => parse_dependencies(lockfile),
          "structure" => detect_structure(root)
        }
      end

      def self.detect_test_framework(root, lockfile)
        has_spec_dir = File.directory?(File.join(root, "spec"))
        has_test_dir = File.directory?(File.join(root, "test"))
        lock = lockfile.to_s
        has_rspec = lock.include?("rspec-rails (") || lock.include?("rspec-core (")
        has_minitest = lock.include?("minitest (")
        if has_rspec && (has_spec_dir || lock.include?("rspec"))
          return has_test_dir && has_minitest ? "both" : "rspec"
        end
        if has_test_dir
          return "minitest"
        end
        if has_spec_dir
          return "rspec"
        end
        "unknown"
      end
      private_class_method :detect_test_framework

      def self.detect_database_adapter(root, lockfile)
        db_yml = read_text(File.join(root, "config/database.yml"), Limits::DATABASE_YML_MAX_BYTES)
        if db_yml
          begin
            data = StrictYaml.parse(db_yml, File.join(root, "config/database.yml"))
            adapter = extract_adapter(data)
            return adapter if adapter
          rescue StandardError
            nil
          end
        end
        lock = lockfile.to_s
        return "postgresql" if lock.include?("pg (")
        return "mysql2" if lock.include?("mysql2 (")
        return "sqlite3" if lock.include?("sqlite3 (")
        return "trilogy" if lock.include?("trilogy (")

        nil
      end
      private_class_method :detect_database_adapter

      def self.extract_adapter(data)
        return nil unless data.is_a?(Hash)

        %w[development test production].each do |env|
          section = data[env]
          next unless section.is_a?(Hash)

          adapter = section["adapter"]
          return adapter.to_s.strip if adapter.is_a?(String) && !adapter.strip.empty?
        end
        default = data["default"]
        if default.is_a?(Hash)
          adapter = default["adapter"]
          return adapter.to_s.strip if adapter.is_a?(String) && !adapter.strip.empty?
        end
        nil
      end
      private_class_method :extract_adapter

      def self.parse_dependencies(lockfile)
        return [] unless lockfile

        gems = []
        lockfile.each_line do |line|
          next unless line.match?(/\A\s{4}[a-z0-9_\-]+\s+\(/)

          match = line.match(/\A\s{4}([a-z0-9_\-]+)\s+\(([^)]+)\)/)
          next unless match

          gems << { "name" => match[1], "version" => match[2].strip }
          break if gems.length >= Limits::DEPENDENCIES_MAX
        end
        gems
      end
      private_class_method :parse_dependencies

      def self.detect_structure(root)
        counts = {}
        counts["app_models"] = count_files(root, "app/models/**/*.rb")
        counts["app_controllers"] = count_files(root, "app/controllers/**/*.rb")
        counts["app_jobs"] = count_files(root, "app/jobs/**/*.rb")
        counts["app_mailers"] = count_files(root, "app/mailers/**/*.rb")
        counts["app_helpers"] = count_files(root, "app/helpers/**/*.rb")
        counts["app_views"] = count_files(root, "app/views/**/*")
        counts["has_routes"] = File.file?(File.join(root, "config/routes.rb"))
        counts["has_schema"] = File.file?(File.join(root, "db/schema.rb"))
        counts["has_structure_sql"] = File.file?(File.join(root, "db/structure.sql"))
        counts["has_app"] = File.directory?(File.join(root, "app"))
        counts
      rescue StandardError
        {}
      end
      private_class_method :detect_structure

      def self.count_files(root, pattern)
        paths = Dir.glob(File.join(root, pattern))
        paths.count { |path| File.file?(path) }
      rescue StandardError
        0
      end
      private_class_method :count_files

      def self.read_text(path, max_bytes)
        return nil unless File.file?(path)
        return nil if File.size(path) > max_bytes rescue nil

        text = File.binread(path)
        return nil if text.bytesize > max_bytes

        text.force_encoding(Encoding::UTF_8)
        return nil unless text.valid_encoding?

        text
      rescue StandardError
        nil
      end
      private_class_method :read_text
    end
  end
end
