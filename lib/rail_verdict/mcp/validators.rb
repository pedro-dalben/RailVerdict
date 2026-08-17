# frozen_string_literal: true

module RailVerdict
  module MCP
    module Validators
      FINDING_REF_PATTERN = /\A(?:rv:[0-9a-f]{20}|sha256:[0-9a-f]{64})\z/
      BASE_REVISION_PATTERN = /\A[0-9a-f]{7,64}\z/
      MAX_FINDING_REF_BYTES = 512

      def self.validate_finding_ref(value)
        raise ArgumentError, "finding_ref must be a non-empty string" unless value.is_a?(String) && !value.strip.empty?
        raise ArgumentError, "finding_ref exceeds #{MAX_FINDING_REF_BYTES} bytes" if value.bytesize > MAX_FINDING_REF_BYTES
        raise ArgumentError, "finding_ref contains NUL byte" if value.include?("\u0000")
        raise ArgumentError, "finding_ref has invalid format" unless value.strip.match?(FINDING_REF_PATTERN)

        value.strip
      end

      def self.validate_limit(value, default: 50, max: 100)
        return default if value.nil?

        raise ArgumentError, "limit must be an integer" unless value.is_a?(Integer)
        raise ArgumentError, "limit must be between 1 and #{max}" unless value.between?(1, max)

        value
      end

      def self.validate_offset(value)
        return 0 if value.nil?

        raise ArgumentError, "offset must be an integer >= 0" unless value.is_a?(Integer) && value >= 0

        value
      end

      def self.validate_base_revision(value)
        return nil if value.nil?
        str = value.to_s.strip
        return nil if str.empty?
        raise ArgumentError, "base revision contains NUL byte" if str.include?("\u0000")
        raise ArgumentError, "base revision has invalid format" unless str.match?(BASE_REVISION_PATTERN)

        str
      end

      def self.validate_boolean(value, name)
        return false if value.nil?
        return value if value == true || value == false

        raise ArgumentError, "#{name} must be a boolean"
      end

      def self.validate_severity(value)
        return nil if value.nil?
        allowed = %w[info low medium high critical]
        raise ArgumentError, "severity must be one of #{allowed.join(', ')}" unless allowed.include?(value)

        value
      end

      def self.validate_state(value)
        return nil if value.nil?
        allowed = %w[observed introduced existing resolved changed moved suppressed waived]
        raise ArgumentError, "state must be one of #{allowed.join(', ')}" unless allowed.include?(value)

        value
      end

      def self.validate_packet_id(value)
        raise ArgumentError, "packet_id must be a non-empty string" unless value.is_a?(String) && !value.strip.empty?
        raise ArgumentError, "packet_id has invalid format" unless value.strip.match?(/\Asha256:[0-9a-f]{64}\z/)

        value.strip
      end

      def self.scrub_text(value)
        value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD").gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "?")
      end
    end
  end
end
