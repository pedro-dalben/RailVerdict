# frozen_string_literal: true

require "digest"
require "json"

module RailVerdict
  module Fingerprint
    VERSION = 1
    ALGORITHM = "sha256"
    PAYLOAD_SCHEMA = "https://railverdict.dev/fingerprint-payload/v1"
    LEGACY_PAYLOAD_SCHEMA = "https://railverdict.dev/fingerprint-payload/v0.1"
    FINGERPRINT_PATTERN = /\Asha256:[0-9a-f]{64}\z/

    class IncompatibleError < RailVerdict::Error; end

    module_function

    def canonical_payload(analyzer:, rule_id:, path:, message:)
      analyzer = normalize_field(analyzer, "analyzer")
      rule_id = normalize_field(rule_id, "rule_id")
      path = normalize_path(path)
      message = normalize_message(message)
      {
        "payload_schema" => PAYLOAD_SCHEMA,
        "fingerprint_version" => VERSION,
        "algorithm" => ALGORITHM,
        "analyzer" => analyzer,
        "rule_id" => rule_id,
        "path" => path,
        "message" => message
      }
    end

    def canonical_json(analyzer:, rule_id:, path:, message:)
      payload = canonical_payload(analyzer: analyzer, rule_id: rule_id, path: path, message: message)
      sorted = payload.keys.sort.to_h { |key| [key, payload.fetch(key)] }
      JSON.generate(sorted)
    end

    def hexdigest(analyzer:, rule_id:, path:, message:)
      "sha256:#{Digest::SHA256.hexdigest(canonical_json(analyzer: analyzer, rule_id: rule_id, path: path, message: message))}"
    end

    def valid?(fingerprint)
      fingerprint.is_a?(String) && fingerprint.match?(FINGERPRINT_PATTERN)
    end

    def normalize_field(value, _name)
      value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").strip
    end
    private_class_method :normalize_field

    def normalize_path(path)
      raw = path.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").strip
      raw = raw.delete_prefix("./")
      raw = raw.delete_prefix("/")
      raw = raw.unicode_normalize(:nfc) if raw.respond_to?(:unicode_normalize)
      raw
    end
    private_class_method :normalize_path

    def normalize_message(message)
      raw = message.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").strip
      raw = raw.gsub(/\s+/, " ")
      raw = raw.unicode_normalize(:nfc) if raw.respond_to?(:unicode_normalize)
      raw = raw[0, 4096] if raw.bytesize > 4096
      raw = raw.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")
      raw.bytesize > 4096 ? raw.byteslice(0, 4096).encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?") : raw
    end
    private_class_method :normalize_message
  end
end
