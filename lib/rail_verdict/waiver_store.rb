# frozen_string_literal: true

require "json"
require "pathname"

module RailVerdict
  class WaiverStore
    DEFAULT_FILENAME = ".railverdict-waivers.json"

    def self.default_path(repository_root)
      File.join(File.realpath(repository_root), DEFAULT_FILENAME)
    end

    def self.resolve_path(repository_root:, configuration:, waiver_override: nil)
      root = File.realpath(repository_root)
      if waiver_override && !waiver_override.to_s.strip.empty?
        path = waiver_override.to_s
        return Pathname.new(path).absolute? ? path : File.expand_path(path, root)
      end
      if configuration.respond_to?(:waivers_path) && configuration.waivers_path
        configured = configuration.waivers_path.to_s
        return Pathname.new(configured).absolute? ? configured : File.expand_path(configured, root)
      end
      File.join(root, DEFAULT_FILENAME)
    end

    def self.read(path)
      unless File.file?(path)
        raise Waiver::IncompatibleError, "waiver file not found at #{path}"
      end
      raw = File.binread(path)
      begin
        data = JSON.parse(raw)
      rescue JSON::ParserError => error
        raise Waiver::IncompatibleError, "waiver file at #{path} is corrupted: #{error.message}; fix the file or remove the waiver"
      end
      errors = SchemaValidator.validate_waivers(data)
      unless errors.empty?
        raise Waiver::IncompatibleError, "waiver file at #{path} is incompatible: #{errors.join('; ')}; fix the file or remove the waiver"
      end
      seen = {}
      data.fetch("waivers").each do |waiver|
        fingerprint = waiver.fetch("fingerprint")
        if seen.key?(fingerprint)
          raise Waiver::IncompatibleError, "waiver file at #{path} contains duplicate fingerprint #{fingerprint}"
        end
        seen[fingerprint] = true
        Waiver.validate_hash(waiver)
      end
      data["waivers"].sort_by { |waiver| waiver.fetch("fingerprint") }.map { |hash| Waiver.new(hash) }
    end

    def self.read_optional(path)
      return [] unless File.file?(path)

      read(path)
    end
  end
end
