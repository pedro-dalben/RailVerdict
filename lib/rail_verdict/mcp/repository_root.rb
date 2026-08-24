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
        require_relative "../path_safety"
        RailVerdict::PathSafety.contained?(root, path)
      end
    end
  end
end
