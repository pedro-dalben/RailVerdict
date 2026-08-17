# frozen_string_literal: true

require "digest"

module RailVerdict
  module Repair
    module Boundary
      def self.snapshot(repository_root:, configuration:, outcome:)
        config_digest = configuration&.digest
        baseline_path = configuration ? Baseline.resolve_path(repository_root: repository_root, configuration: configuration) : nil
        waiver_path = configuration ? WaiverStore.resolve_path(repository_root: repository_root, configuration: configuration) : nil
        baseline_digest = file_digest(baseline_path)
        waivers_digest = file_digest(waiver_path)
        source_revision = outcome&.context&.revision
        base_revision = outcome&.context&.git_context&.base rescue nil
        base_revision ||= outcome&.result&.git&.fetch("base", nil) rescue nil
        {
          "configuration_digest" => config_digest || Digest::SHA256.hexdigest(""),
          "baseline_digest" => baseline_digest,
          "waivers_digest" => waivers_digest,
          "base_revision" => base_revision,
          "source_revision" => source_revision
        }
      end

      def self.file_digest(path)
        return nil unless path && File.file?(path)

        Digest::SHA256.hexdigest(File.binread(path))
      rescue StandardError
        nil
      end
      private_class_method :file_digest
    end
  end
end
