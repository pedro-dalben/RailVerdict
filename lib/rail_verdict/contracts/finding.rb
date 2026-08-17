# frozen_string_literal: true

require "digest"
require "json"

module RailVerdict
  class Finding
    SCHEMA_VERSION = "1.0"
    FINGERPRINT_PAYLOAD_SCHEMA = "https://railverdict.dev/fingerprint-payload/v1"
    LEGACY_FINGERPRINT_PAYLOAD_SCHEMA = "https://railverdict.dev/fingerprint-payload/v0.1"
    FINGERPRINT_PATTERN = /\Asha256:[0-9a-f]{64}\z/
    LOCATION_PATH_PATTERN = %r{
      \A
      (?!/)
      (?!.*\\)
      (?!.*//)
      (?!(?:\.{1,2})(?:/|\z))
      (?!.* / (?:\.{1,2}) (?:/|\z))
      [^\u0000-\u001f/]+
      (?:/[^\u0000-\u001f/]+)*
      \z
    }x

    ORIGINS = %w[deterministic runtime ai custom].freeze
    SEVERITIES = %w[info low medium high critical].freeze
    CONFIDENCES = %w[low medium high].freeze
    STATES = %w[observed introduced existing resolved changed moved suppressed waived].freeze

    attr_reader :id, :fingerprint, :origin, :analyzer, :rule_id, :category, :severity,
                :confidence, :state, :evidence_ref, :location, :message

    def self.fingerprint_for(analyzer:, rule_id:, path:, message:)
      Fingerprint.hexdigest(analyzer: analyzer, rule_id: rule_id, path: path, message: message)
    end

    def self.id_for(fingerprint)
      hex = fingerprint.delete_prefix("sha256:")
      "rv:#{hex.slice(0, 20)}"
    end

    def initialize(fingerprint:, origin:, analyzer:, rule_id:, category:, severity:, confidence:,
                   state:, evidence_ref:, location:, message:)
      @fingerprint = require_match(fingerprint, FINGERPRINT_PATTERN, "fingerprint")
      @origin = require_member(origin, ORIGINS, "origin")
      @analyzer = require_nonempty(analyzer, "analyzer", 256)
      @rule_id = require_nonempty(rule_id, "rule_id", 256)
      @category = require_nonempty(category, "category", 256)
      @severity = require_member(severity, SEVERITIES, "severity")
      @confidence = require_member(confidence, CONFIDENCES, "confidence")
      @state = require_member(state, STATES, "state")
      @evidence_ref = require_nonempty(evidence_ref, "evidence_ref", 512)
      @location = validate_location(location)
      @message = require_nonempty(message, "message", 4096)
      @id = Finding.id_for(@fingerprint).freeze
      @location.freeze
      @analyzer.freeze
      @rule_id.freeze
      @category.freeze
      @evidence_ref.freeze
      @message.freeze
      freeze
    end

    def schema_version
      SCHEMA_VERSION
    end

    def sort_key
      [
        location.fetch("path").to_s,
        location["start_line"] || -1,
        location["end_line"] || -1,
        analyzer,
        rule_id,
        fingerprint,
        id
      ]
    end

    def to_schema_h
      {
        "schema_version" => SCHEMA_VERSION,
        "id" => id,
        "fingerprint" => fingerprint,
        "origin" => origin,
        "analyzer" => analyzer,
        "rule_id" => rule_id,
        "category" => category,
        "severity" => severity,
        "confidence" => confidence,
        "state" => state,
        "evidence_ref" => evidence_ref,
        "location" => location,
        "message" => message
      }
    end

    private

    def require_match(value, pattern, name)
      raise ArgumentError, "#{name} is invalid" unless value.is_a?(String) && value.match?(pattern)

      value.frozen? ? value : value.dup.freeze
    end

    def require_member(value, allowed, name)
      raise ArgumentError, "#{name} must be one of #{allowed.join(', ')}" unless allowed.include?(value)

      value
    end

    def require_nonempty(value, name, max_length)
      unless value.is_a?(String) && value.valid_encoding? && !value.empty? && value.bytesize <= max_length
        raise ArgumentError, "#{name} must be a non-empty string of at most #{max_length} bytes"
      end

      value
    end

    def validate_location(location)
      raise ArgumentError, "location must be a Hash" unless location.is_a?(Hash)

      unknown = location.keys - %w[path start_line end_line]
      raise ArgumentError, "location contains unknown fields: #{unknown.join(', ')}" unless unknown.empty?

      path = location.fetch("path") do
        raise ArgumentError, "location requires a path"
      end
      unless path.is_a?(String) && path.valid_encoding? && path.match?(LOCATION_PATH_PATTERN)
        raise ArgumentError, "location.path must be a clean repository-relative path"
      end

      result = { "path" => path.dup.freeze }
      start_line = location["start_line"]
      end_line = location["end_line"]
      result["start_line"] = validate_line(start_line, "start_line") unless start_line.nil?
      result["end_line"] = validate_line(end_line, "end_line") unless end_line.nil?

      if !start_line.nil? && !end_line.nil? && end_line < start_line
        raise ArgumentError, "location end_line cannot precede start_line"
      end

      result
    end

    def validate_line(value, name)
      unless value.is_a?(Integer) && value >= 1
        raise ArgumentError, "location #{name} must be an integer >= 1"
      end

      value
    end
  end
end
