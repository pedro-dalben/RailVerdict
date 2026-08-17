# frozen_string_literal: true

module RailVerdict
  module Intelligence
    module Redactor
      Result = Struct.new(:manifest, :redacted_count, :secret_detected, keyword_init: true)

      def self.redact(manifest, trust: "redacted")
        snippets = manifest.snippets || []
        redacted = 0
        secret_detected = false
        filtered = []

        snippets.each do |snippet|
          path = snippet["path"] || snippet[:path]
          content = snippet["content"] || snippet[:content] || ""

          if SecretDetector.filename_secret?(path)
            redacted += 1
            secret_detected = true
            next
          end

          if SecretDetector.content_secret?(content)
            secret_detected = true
            if trust == "full"
              return Result.new(manifest: nil, redacted_count: redacted, secret_detected: true)
            else
              redacted += 1
              content = "[REDACTED: probable secret detected]"
            end
          end

          filtered << snippet.merge("content" => content)
        end

        new_manifest = Manifest.new(
          finding_id: manifest.finding_id,
          fingerprint: manifest.fingerprint,
          finding: manifest.finding,
          snippets: filtered,
          rails_facts: manifest.rails_facts,
          git_slice: manifest.git_slice,
          comparison_slice: manifest.comparison_slice,
          policy_reason: manifest.policy_reason
        )
        Result.new(manifest: new_manifest, redacted_count: redacted, secret_detected: secret_detected)
      end
    end
  end
end
