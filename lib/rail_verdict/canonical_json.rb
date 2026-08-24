# frozen_string_literal: true

require "json"

module RailVerdict
  module CanonicalJSON
    module_function

    def generate(value)
      JSON.generate(canonicalize(value))
    end

    def canonicalize(value)
      case value
      when Hash
        value.keys.sort_by(&:to_s).to_h { |key| [key, canonicalize(value[key])] }
      when Array
        value.map { |item| canonicalize(item) }
      when String
        scrub_text(value)
      else
        value
      end
    end

    def scrub_text(text)
      text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "\uFFFD")
          .gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "?")
    end
  end
end
