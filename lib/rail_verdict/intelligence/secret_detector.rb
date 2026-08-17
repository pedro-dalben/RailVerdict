# frozen_string_literal: true

module RailVerdict
  module Intelligence
    module SecretDetector
      FILENAME_PATTERNS = [
        /\.env(\.|$)/,
        /master\.key$/,
        /credentials.*\.key$/,
        /\.pem$/,
        /\.key$/,
        /id_rsa/,
        /\.p12$/,
        %r{(^|/)tmp/},
        %r{(^|/)log/.*\.log$}
      ].freeze

      CONTENT_PATTERNS = [
        /AKIA[0-9A-Z]{16}/,
        /BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY/,
        /(?:api[_-]?key|secret|token|password)\s*[:=]\s*['"]?[^'"\s]{8,}/i,
        /gh[pousr]_[A-Za-z0-9_]{20,}/,
        /eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/,
        /[A-Za-z0-9_\-]{32,}/
      ].freeze

      def self.filename_secret?(path)
        p = path.to_s
        FILENAME_PATTERNS.any? { |re| p.match?(re) }
      end

      def self.content_secret?(text)
        t = text.to_s
        CONTENT_PATTERNS.any? { |re| t.match?(re) }
      end

      def self.probable_secret?(path: nil, content: nil)
        return true if path && filename_secret?(path)
        return true if content && content_secret?(content)

        false
      end
    end
  end
end
