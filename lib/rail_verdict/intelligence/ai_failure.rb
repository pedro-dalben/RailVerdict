# frozen_string_literal: true

module RailVerdict
  module Intelligence
    class AIFailure
      CODES = %w[
        disabled
        provider_unavailable
        authentication_failed
        rate_limited
        timed_out
        budget_exhausted
        context_rejected
        secret_detected
        response_invalid
        schema_invalid
        context_too_large
        manifest_invalid
      ].freeze

      attr_reader :code, :message

      def initialize(code:, message:)
        raise ArgumentError, "invalid code" unless CODES.include?(code.to_s)

        @code = code.to_s.freeze
        @message = sanitize(message.to_s).freeze
        freeze
      end

      def to_h
        { "code" => code, "message" => message }
      end

      private

      def sanitize(text)
        cleaned = text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")
        cleaned = cleaned.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "?")
        cleaned.strip[0, 1024]
      end
    end
  end
end
