# frozen_string_literal: true

module RailVerdict
  module MCP
    module RepositoryRoot
      def self.resolve(requested)
        raw = requested && !requested.to_s.strip.empty? ? requested.to_s.strip : Dir.pwd
        expanded = File.expand_path(raw)
        real = begin
          File.realpath(expanded)
        rescue Errno::ENOENT
          expanded
        end
        raise ArgumentError, "repository root is not a directory: #{real}" unless File.directory?(real)

        real.freeze
      end

      def self.contained?(root, path)
        root = File.realpath(root) rescue File.expand_path(root)
        target = File.expand_path(path, root)
        real_target = begin
          File.realpath(target)
        rescue Errno::ENOENT
          target
        end
        real_target == root || real_target.start_with?(root + File::SEPARATOR)
      end
    end
  end
end
