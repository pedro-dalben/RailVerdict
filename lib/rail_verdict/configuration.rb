# frozen_string_literal: true

require "digest"

module RailVerdict
  class Configuration
    DEFAULT_FILENAME = ".railverdict.yml"
    CONFIGURATION_VERSION = 1
    UTF8_BOM = "\xEF\xBB\xBF".b

    attr_reader :version, :mode, :analyzers, :source_path, :digest

    def self.load(path)
      source_path = path.to_s
      unless File.file?(source_path)
        raise ConfigurationError.new(
          "configuration file not found: #{source_path}",
          source_path: source_path
        )
      end

      bytes = File.binread(source_path)
      text = decode_utf8(bytes, source_path)
      data = load_strict_yaml(text, source_path)
      validate_schema(data, source_path)
      new(data, source_path, bytes)
    end

    def self.decode_utf8(bytes, source_path)
      if bytes.start_with?(UTF8_BOM)
        raise ConfigurationError.new(
          "#{source_path}: configuration must be UTF-8 without a byte order mark",
          source_path: source_path
        )
      end

      text = bytes.dup.force_encoding(Encoding::UTF_8)
      unless text.valid_encoding?
        raise ConfigurationError.new(
          "#{source_path}: configuration must be valid UTF-8",
          source_path: source_path
        )
      end

      text
    end

    def self.load_strict_yaml(text, source_path)
      StrictYaml.parse(text, source_path)
    rescue StrictYaml::Error => error
      raise ConfigurationError.new(
        "#{error.message}",
        source_path: source_path,
        property_path: error.property_path
      )
    end

    def self.validate_schema(data, source_path)
      unless data.is_a?(Hash)
        raise ConfigurationError.new(
          "#{source_path}: $: configuration must be a mapping",
          source_path: source_path,
          property_path: "$"
        )
      end

      errors = SchemaValidator.validate_configuration(data)
      return if errors.empty?

      raise ConfigurationError.new(
        "invalid configuration #{source_path}: #{errors.join('; ')}",
        source_path: source_path,
        property_path: errors.first.to_s.split(":").first
      )
    end

    def initialize(data, source_path, bytes)
      @version = data.fetch("version")
      @mode = data.fetch("mode").freeze
      @analyzers = deep_freeze(data.fetch("analyzers"))
      @source_path = source_path.dup.freeze
      @digest = Digest::SHA256.hexdigest(bytes).freeze
      freeze
    end

    def analyzer_selection(name)
      @analyzers.fetch(name)
    end

    def analyzer_enabled?(name)
      analyzer_selection(name).fetch("enabled")
    end

    def analyzer_required?(name)
      analyzer_selection(name).fetch("required")
    end

    private

    def deep_freeze(value)
      case value
      when Hash
        value.each { |key, child| deep_freeze(child); key.freeze }
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
