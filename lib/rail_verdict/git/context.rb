# frozen_string_literal: true

require "set"
require "pathname"

module RailVerdict
  module Git
    class ChangedFile
      attr_reader :status, :path, :old_path, :new_path, :score
      attr_accessor :binary

      def initialize(status:, path:, old_path:, new_path:, score:, binary: false)
        @status = status
        @path = path
        @old_path = old_path
        @new_path = new_path
        @score = score
        @binary = binary
        freeze
      end

      def to_h
        { "status" => status.to_s, "path" => path, "old_path" => old_path, "new_path" => new_path, "score" => score, "binary" => binary }
      end
    end

    class Context
      attr_reader :repository_root, :head, :base, :merge_base, :changed_files, :changed_line_set, :binary_paths, :conflicted_paths

      def initialize(repository_root:, head:, base:, merge_base:, changed_files:, changed_line_set:, binary_paths:, conflicted_paths:)
        @repository_root = repository_root.dup.freeze
        @head = head.dup.freeze
        @base = base.dup.freeze
        @merge_base = merge_base.dup.freeze
        @changed_files = changed_files.map(&:freeze).freeze
        @changed_line_set = deep_freeze_line_set(changed_line_set)
        @binary_paths = binary_paths.dup.freeze
        @conflicted_paths = conflicted_paths.dup.freeze
        freeze
      end

      def to_h
        {
          "repository_root" => repository_root,
          "head" => head,
          "base" => base,
          "merge_base" => merge_base,
          "changed_files" => changed_files.map(&:to_h),
          "changed_line_set" => changed_line_set,
          "binary_paths" => binary_paths.sort,
          "conflicted_paths" => conflicted_paths.sort
        }
      end

      def rename_map
        map = {}
        changed_files.each do |file|
          next unless file.status == :renamed

          map[file.new_path] = file.old_path if file.new_path && file.old_path
        end
        map.freeze
      end

      def self.build(repository_root:, base_override:, configuration:, runner: ProcessRunner)
        root = File.realpath(repository_root)
        raise Git::NotARepository, "repository root does not exist: #{repository_root}" unless File.directory?(root)

        git_root = resolve_git_root(root, runner: runner)
        unless Pathname.new(git_root) == Pathname.new(root) || root.start_with?(git_root + File::SEPARATOR) || git_root == root
          git_root = root if File.directory?(File.join(root, ".git"))
        end
        unless Dir.exist?(File.join(git_root, ".git")) || File.file?(File.join(git_root, ".git"))
          toplevel = git_toplevel(root, runner: runner)
          if toplevel && File.directory?(toplevel)
            git_root = toplevel
          end
        end
        repository_root = git_root

        head = resolve_head(repository_root, runner: runner)
        base_raw = resolve_base_raw(base_override, configuration)
        if base_raw.nil? || base_raw.strip.empty?
          raise Git::BaseUnresolvable, "changed scope requires an explicit base: supply --base <revision> or set git.base in .railverdict.yml"
        end
        base = resolve_base_commit(base_raw.strip, repository_root, runner: runner)
        merge_base = resolve_merge_base(base, head, repository_root, runner: runner)
        changed_files, binary_set = resolve_changed_files(merge_base, head, repository_root, runner: runner)
        changed_line_set = resolve_changed_line_set(merge_base, head, changed_files, repository_root, runner: runner)
        conflicted = resolve_conflicts(repository_root, runner: runner)
        binary_paths = (binary_set.to_a + changed_line_set.select { |_, v| v.nil? }.keys).uniq.sort.freeze
        filtered_line_set = changed_line_set.reject { |_, v| v.nil? }

        new(
          repository_root: repository_root,
          head: head,
          base: base,
          merge_base: merge_base,
          changed_files: changed_files,
          changed_line_set: filtered_line_set,
          binary_paths: binary_paths,
          conflicted_paths: conflicted
        )
      end

      def self.resolve_git_root(root, runner:)
        result = Command.run(["rev-parse", "--show-toplevel"], chdir: root, runner: runner)
        interpreted = begin
          Command.interpret(result, chdir: root)
        rescue Git::Error
          return root
        end
        return root unless interpreted.exit_code == 0

        toplevel = interpreted.stdout.to_s.strip
        toplevel = toplevel.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").strip
        toplevel = toplevel.unicode_normalize(:nfc) if toplevel.respond_to?(:unicode_normalize)
        toplevel.empty? ? root : File.realpath(toplevel)
      rescue Errno::ENOENT, Errno::EACCES
        root
      end
      private_class_method :resolve_git_root

      def self.git_toplevel(root, runner:)
        result = Command.run(["rev-parse", "--show-toplevel"], chdir: root, runner: runner)
        interpreted = begin
          Command.interpret(result, chdir: root)
        rescue Git::Error
          return nil
        end
        return nil unless interpreted.exit_code == 0

        out = interpreted.stdout.to_s.strip
        out.empty? ? nil : out
      end
      private_class_method :git_toplevel

      def self.resolve_head(root, runner:)
        result = Command.run(["rev-parse", "HEAD"], chdir: root, runner: runner)
        interpreted = Command.interpret(result, chdir: root)
        unless interpreted.exit_code == 0
          raise Git::Error, "cannot resolve HEAD: #{interpreted.stderr.to_s.strip[0, 512]}"
        end
        sha = interpreted.stdout.to_s.strip
        unless sha.match?(/\A[0-9a-f]{7,64}\z/)
          raise Git::Error, "HEAD is not a valid commit SHA: #{sha.inspect}"
        end
        full = resolve_full_sha(sha, root, runner: runner)
        full || sha
      end
      private_class_method :resolve_head

      def self.resolve_full_sha(sha, root, runner:)
        result = Command.run(["rev-parse", sha], chdir: root, runner: runner)
        interpreted = begin
          Command.interpret(result, chdir: root)
        rescue Git::Error
          return nil
        end
        return nil unless interpreted.exit_code == 0

        out = interpreted.stdout.to_s.strip
        out.match?(/\A[0-9a-f]{40,64}\z/) ? out : nil
      end
      private_class_method :resolve_full_sha

      def self.resolve_base_raw(base_override, configuration)
        if base_override && !base_override.to_s.strip.empty?
          return base_override.to_s.strip
        end
        if configuration.respond_to?(:git_base) && configuration.git_base && !configuration.git_base.to_s.strip.empty?
          return configuration.git_base.to_s.strip
        end
        nil
      end
      private_class_method :resolve_base_raw

      def self.resolve_base_commit(base_raw, root, runner:)
        result = Command.run(["rev-parse", "--verify", "#{base_raw}^{commit}"], chdir: root, runner: runner)
        interpreted = begin
          Command.interpret(result, chdir: root)
        rescue Git::Unavailable, Git::Timeout, Git::Truncated => error
          raise error
        rescue Git::Error
          raise Git::BaseUnresolvable, "base revision is not resolvable: #{base_raw.inspect}"
        end
        unless interpreted.exit_code == 0
          message = interpreted.stderr.to_s.strip
          if message.include?("not a valid object name") || message.include?("needed a single revision")
            raise Git::BaseUnresolvable, "base revision is not resolvable: #{base_raw.inspect}"
          end
          raise Git::BaseUnresolvable, "base revision is not resolvable: #{base_raw.inspect} (#{message[0, 512]})"
        end
        sha = interpreted.stdout.to_s.strip
        unless sha.match?(/\A[0-9a-f]{7,64}\z/)
          raise Git::BaseUnresolvable, "base did not resolve to a commit: #{base_raw.inspect}"
        end
        sha
      end
      private_class_method :resolve_base_commit

      def self.resolve_merge_base(base, head, root, runner:)
        result = Command.run(["merge-base", base, head], chdir: root, runner: runner)
        interpreted = begin
          Command.interpret(result, chdir: root)
        rescue Git::Unavailable, Git::Timeout, Git::Truncated => error
          raise error
        rescue Git::Error => error
          raise Git::MergeBaseFailure, "cannot resolve merge-base for #{base.inspect} and #{head.inspect}: #{error.message}"
        end
        unless interpreted.exit_code == 0
          stderr = interpreted.stderr.to_s.strip
          if stderr.include?("not a valid object name") || stderr.include?("no merge base")
            raise Git::MergeBaseFailure, "cannot resolve merge-base: history is incomplete or base is unrelated (#{stderr[0, 512]})"
          end
          raise Git::MergeBaseFailure, "cannot resolve merge-base: #{stderr[0, 512]}"
        end
        sha = interpreted.stdout.to_s.strip
        unless sha.match?(/\A[0-9a-f]{7,64}\z/)
          raise Git::MergeBaseFailure, "merge-base did not resolve to a commit"
        end
        sha
      end
      private_class_method :resolve_merge_base

      def self.resolve_changed_files(merge_base, head, root, runner:)
        name_status_raw = run_diff_or_raise(["diff", "--name-status", "-z", "--find-renames", "--diff-filter=ADMR", merge_base, head], root, runner: runner, context: "name-status")
        files = DiffParser.parse_name_status_nul(name_status_raw)

        numstat_raw = run_diff_or_raise(["diff", "--numstat", "-z", "--find-renames", merge_base, head], root, runner: runner, context: "numstat")
        numstat = DiffParser.parse_numstat_rename_nul(numstat_raw)

        binary_set = Set.new
        enriched = files.map do |file|
          key = file.path || file.old_path
          info = numstat[key] if key
          is_binary = !!(info && info[:binary])
          binary_set.add(key) if is_binary
          ChangedFile.new(status: file.status, path: file.path, old_path: file.old_path, new_path: file.new_path, score: file.score, binary: is_binary)
        end

        changed = enriched.reject { |file| file.status == :deleted }.sort_by { |file| file.path.to_s }
        [changed, binary_set]
      end
      private_class_method :resolve_changed_files

      def self.run_diff_or_raise(argv, root, runner:, context:)
        result = Command.run(argv, chdir: root, timeout_seconds: 10.0, max_stdout_bytes: 4 * 1024 * 1024, runner: runner)
        interpreted = Command.interpret(result, chdir: root)
        unless interpreted.exit_code == 0
          raise Git::DiffFailure, "git diff #{context} failed: #{interpreted.stderr.to_s.strip[0, 1024]}"
        end
        interpreted.stdout.dup.force_encoding(Encoding::BINARY)
      end
      private_class_method :run_diff_or_raise

      def self.resolve_changed_line_set(merge_base, head, changed_files, root, runner:)
        return {} if changed_files.empty?

        raw = begin
          run_diff_or_raise(["diff", "-U0", "--no-color", "-z", "--find-renames", merge_base, head], root, runner: runner, context: "unified")
        rescue Git::DiffFailure
          ""
        end
        raw = raw.dup.force_encoding(Encoding::BINARY) if raw
        binary_paths = changed_files.select { |file| file.binary }.map { |file| file.path }.compact
        binary_set = Set.new(binary_paths)
        segments = DiffParser.split_unified_by_nul(raw || "")
        line_set = {}
        segments.each do |path, diff_text|
          normalized = normalize_path_for_lines(path.to_s)
          next if binary_set.include?(normalized)

          exists = changed_files.any? { |file| file.path == normalized }
          next unless exists || changed_files.any? { |file| file.new_path == normalized }

          text = diff_text.to_s
          next if text.empty?

          lines = extract_added_lines(text)
          line_set[normalized] = lines.sort.freeze unless lines.empty?
        end
        line_set.transform_values(&:freeze).freeze
      end
      private_class_method :resolve_changed_line_set

      def self.extract_added_lines(diff_text)
        lines = []
        new_line = nil
        diff_text.each_line do |raw_line|
          if raw_line.start_with?("@@ ")
            match = raw_line.match(/\A@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/)
            new_line = match ? match[1].to_i : nil
            next
          end
          next if new_line.nil?
          next if raw_line.start_with?("diff --git") || raw_line.start_with?("index ") || raw_line.start_with?("--- ") || raw_line.start_with?("+++ ")

          if raw_line.start_with?("+")
            next if raw_line.start_with?("+++ ")

            lines << new_line
            new_line += 1
          elsif raw_line.start_with?("-")
            next
          elsif raw_line.start_with?(" ") || raw_line.start_with?("\\")
            new_line += 1 if raw_line.start_with?(" ")
          end
        end
        lines
      end
      private_class_method :extract_added_lines

      def self.normalize_path_for_lines(path)
        raw = path.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").strip
        raw = raw.delete_prefix("./")
        raw = raw.delete_prefix("/")
        raw = raw.unicode_normalize(:nfc) if raw.respond_to?(:unicode_normalize)
        raw
      end
      private_class_method :normalize_path_for_lines

      def self.resolve_conflicts(root, runner:)
        result = Command.run(["ls-files", "-u", "-z"], chdir: root, runner: runner)
        interpreted = begin
          Command.interpret(result, chdir: root)
        rescue Git::Error
          return [].freeze
        end
        return [].freeze unless interpreted.exit_code == 0

        raw = interpreted.stdout.to_s
        return [].freeze if raw.strip.empty?

        parts = raw.split("\0")
        paths = Set.new
        parts.each do |entry|
          next if entry.strip.empty?

          tab_index = entry.index("\t")
          path = tab_index ? entry[(tab_index + 1)..] : entry
          next if path.nil? || path.strip.empty?

          paths.add(normalize_path_for_lines(path))
        end
        paths.to_a.sort.freeze
      end
      private_class_method :resolve_conflicts

      private

      def deep_freeze_line_set(line_set)
        frozen = {}
        line_set.each do |path, lines|
          frozen[path.dup.freeze] = lines.sort.freeze
        end
        frozen.freeze
      end
    end
  end
end
