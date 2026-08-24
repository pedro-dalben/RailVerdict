# frozen_string_literal: true

module RailVerdict
  # Symlink-aware path containment used by CLI and MCP surfaces.
  module PathSafety
    module_function

    # True when +path+ (absolute or root-relative) resolves, through its
    # deepest EXISTING ancestor, to inside +root+. Trailing nonexistent
    # segments are checked lexically against the resolved ancestor so a
    # symlink cannot escape after creation either.
    def contained?(root, path)
      root_real = File.realpath(root)
      target = File.expand_path(path.to_s, root_real)

      existing = target
      until File.exist?(existing) || File.symlink?(existing)
        parent = File.dirname(existing)
        return false if parent == existing

        existing = parent
      end
      real_existing = File.realpath(existing)
      return false unless real_existing == root_real || real_existing.start_with?(root_real + File::SEPARATOR)

      # Remaining (nonexistent) tail must not traverse upward.
      tail = target[real_existing.length..].to_s
      !tail.split(File::SEPARATOR).include?("..")
    rescue Errno::ENOENT, Errno::EACCES, Errno::ELOOP
      false
    end

    def assert_contained!(root, path, label)
      raise UsageError, "#{label} escapes working directory: #{path}" unless contained?(root, path)

      File.expand_path(path.to_s, File.realpath(root))
    end
  end
end
