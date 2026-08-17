# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module ConstantInferencer
      def self.infer(kind:, path:)
        normalized = path.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?").strip
        normalized = normalized.delete_prefix("./").delete_prefix("/")
        normalized = normalized.unicode_normalize(:nfc) if normalized.respond_to?(:unicode_normalize)

        internal = case kind
                   when "model"
                     strip_prefix(normalized, "app/models/")
                   when "controller"
                     strip_prefix(normalized, "app/controllers/")
                   when "job"
                     strip_prefix(normalized, "app/jobs/")
                   when "mailer"
                     strip_prefix(normalized, "app/mailers/")
                   when "helper"
                     strip_prefix(normalized, "app/helpers/")
                   when "service"
                     strip_prefix(normalized, "app/services/")
                   when "policy"
                     strip_prefix(normalized, "app/policies/")
                   when "component"
                     strip_prefix(normalized, "app/components/")
                   else
                     return nil
                   end
        return nil if internal.nil? || internal.empty?
        return nil unless internal.end_with?(".rb")

        bare = internal.delete_suffix(".rb")
        parts = bare.split("/").reject(&:empty?)
        return nil if parts.empty?

        parts.map { |segment| camelize(segment) }.join("::")
      rescue StandardError
        nil
      end

      def self.strip_prefix(path, prefix)
        return nil unless path.start_with?(prefix)

        path[prefix.length..]
      end
      private_class_method :strip_prefix

      def self.camelize(segment)
        segment.split("_").map { |word| word.empty? ? "" : word[0].upcase + word[1..].to_s }.join
      end
      private_class_method :camelize
    end
  end
end
