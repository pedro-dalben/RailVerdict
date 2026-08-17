# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module Classifier
      KINDS = %w[model controller job mailer helper service policy component view route schema migration test spec config lib unknown].freeze

      PREFIX_MAP = {
        "app/models/" => "model",
        "app/controllers/" => "controller",
        "app/jobs/" => "job",
        "app/mailers/" => "mailer",
        "app/helpers/" => "helper",
        "app/services/" => "service",
        "app/policies/" => "policy",
        "app/components/" => "component",
        "app/views/" => "view"
      }.freeze

      def self.classify(path)
        normalized = normalize(path)
        return "unknown" if normalized.empty?

        PREFIX_MAP.each do |prefix, kind|
          return kind if normalized.start_with?(prefix)
        end

        case normalized
        when "config/routes.rb"
          "route"
        when "db/schema.rb"
          "schema"
        when /\Adb\/migrate\//
          "migration"
        when /\Atest\//
          "test"
        when /\Aspec\//
          "spec"
        when /\Aconfig\//
          "config"
        when /\Alib\//
          "lib"
        else
          "unknown"
        end
      end

      def self.normalize(path)
        raw = path.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").strip
        raw = raw.delete_prefix("./").delete_prefix("/")
        raw = raw.unicode_normalize(:nfc) if raw.respond_to?(:unicode_normalize)
        raw.gsub(%r{//+}, "/")
      end
      private_class_method :normalize
    end
  end
end
