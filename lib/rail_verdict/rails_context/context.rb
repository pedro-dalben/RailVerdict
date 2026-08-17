# frozen_string_literal: true

module RailVerdict
  module RailsContext
    class Context
      attr_reader :detected, :scope, :entries, :unresolved

      def self.build(repository_root:, git_context: nil)
        root = File.realpath(repository_root.to_s) rescue repository_root.to_s
        detected = Detector.detect(repository_root: root)
        scope = git_context ? "changed" : "full"

        if git_context.nil?
          return new(detected: detected, scope: scope, entries: [], unresolved: [])
        end

        changed = git_context.changed_files.map(&:path).compact.sort
        rails_changed = changed.select { |path| Classifier.classify(path) != "unknown" }
        rails_changed = rails_changed.reject do |path|
          full = File.join(root, path)
          File.file?(full) && File.size(full) > Limits::MAX_FILE_BYTES rescue false
        end.first(Limits::MAX_FILES)

        entries = rails_changed.map do |source_path|
          kind = Classifier.classify(source_path)
          constant = ConstantInferencer.infer(kind: kind, path: source_path)
          related = []
          unresolved = []

          related.concat(Resolvers::TestCandidates.for(repository_root: root, kind: kind, path: source_path))
          related.concat(Resolvers::PolicyResolver.for(repository_root: root, kind: kind, path: source_path, constant: constant))
          related.concat(Resolvers::ViewResolver.for(repository_root: root, kind: kind, path: source_path, constant: constant))
          related.concat(Resolvers::SchemaResolver.for(repository_root: root, kind: kind, constant: constant, path: source_path))
          if kind == "model"
            assocs = Resolvers::AssociationExtractor.extract(repository_root: root, path: source_path)
            assocs.each do |assoc|
              related << { "path" => source_path, "relationship" => "association:#{assoc['macro']} :#{assoc['name']}", "confidence" => assoc["confidence"], "provenance" => assoc["provenance"] }
            end
          end
          if kind == "controller" || source_path == "config/routes.rb"
            related.concat(Resolvers::RouteResolver.for(repository_root: root, kind: kind, constant: constant))
          end

          related = related.first(Limits::MAX_RELATED).sort_by { |item| [item["path"], item["relationship"]] }

          scan = kind == "controller" ? Resolvers::RouteScanner.scan(repository_root: root) : nil
          if scan && scan[:unresolved]
            unresolved << { "source_path" => source_path, "reason" => "dynamic_route" }
          end

          {
            "source_path" => source_path,
            "kind" => kind,
            "constant" => constant,
            "confidence" => constant ? "exact" : "conventional",
            "provenance" => "path:#{source_path}",
            "related" => related,
            "unresolved" => unresolved
          }
        end.sort_by { |entry| entry["source_path"] }

        unresolved_global = []
        route_scan = Resolvers::RouteScanner.scan(repository_root: root)
        if route_scan[:unresolved]
          unresolved_global << { "source_path" => "config/routes.rb", "reason" => "dynamic_dsl" }
        end
        has_structure = File.file?(File.join(root, "db/structure.sql"))
        if has_structure
          unresolved_global << { "source_path" => "db/structure.sql", "reason" => "structure_sql_not_parsed" }
        end

        new(detected: detected, scope: scope, entries: entries, unresolved: unresolved_global)
      rescue StandardError
        fallback_detected = begin; Detector.detect(repository_root: root); rescue StandardError; {}; end
        new(detected: fallback_detected, scope: git_context ? "changed" : "full", entries: [], unresolved: [])
      end

      def initialize(detected:, scope:, entries:, unresolved:)
        @detected = deep_freeze(detected)
        @scope = scope.dup.freeze
        @entries = deep_freeze(entries)
        @unresolved = deep_freeze(unresolved)
        freeze
      end

      def to_h
        result = {
          "detected" => detected,
          "scope" => scope,
          "entries" => entries
        }
        result["unresolved"] = unresolved unless unresolved.empty?
        result
      end

      private

      def deep_freeze(value)
        case value
        when Hash
          value.each { |key, child| key.freeze if key.is_a?(String); deep_freeze(child) }
          value.freeze
        when Array
          value.each { |child| deep_freeze(child) }
          value.freeze
        when String
          value.freeze
        else
          value
        end
        value
      end
    end
  end
end
