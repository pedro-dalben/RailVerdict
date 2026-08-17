# frozen_string_literal: true

require "json"
require "time"

module RailVerdict
  class Waiver
    SCHEMA_VERSION = "1.0"

    class IncompatibleError < RailVerdict::Error; end

    attr_reader :hash

    def initialize(hash)
      @hash = hash.freeze
      freeze
    end

    def fingerprint
      @hash.fetch("fingerprint")
    end

    def to_h
      @hash
    end

    def self.valid_fingerprint?(value)
      value.is_a?(String) && value.match?(Fingerprint::FINGERPRINT_PATTERN)
    end

    def self.active?(waiver, clock: Time.now.utc)
      hash = waiver.is_a?(Hash) ? waiver : waiver.to_h
      created_at = parse_time(hash["created_at"] || hash[:created_at])
      expires_at = parse_time(hash["expires_at"] || hash[:expires_at])
      return false unless created_at && expires_at

      clock >= created_at && clock < expires_at
    end

    def self.validate_hash(hash)
      errors = SchemaValidator.validate_waiver(hash)
      unless errors.empty?
        raise IncompatibleError, "waiver invalid: #{errors.join('; ')}"
      end
      created_at = parse_time(hash["created_at"])
      expires_at = parse_time(hash["expires_at"])
      raise IncompatibleError, "waiver expires_at must be after created_at" unless created_at && expires_at && expires_at > created_at
      raise IncompatibleError, "waiver timestamps must be UTC (Z)" unless utc_string?(hash["created_at"]) && utc_string?(hash["expires_at"])

      hash
    end

    def self.parse_time(value)
      return nil if value.nil?

      Time.iso8601(value.to_s).utc
    rescue ArgumentError
      nil
    end
    private_class_method :parse_time

    def self.utc_string?(value)
      value.to_s.end_with?("Z")
    end
    private_class_method :utc_string?
  end
end
