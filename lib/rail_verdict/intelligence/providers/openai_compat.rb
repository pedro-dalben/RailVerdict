# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module RailVerdict
  module Intelligence
    module Providers
      class OpenAICompatProvider
        include AIProvider

        ENDPOINT = "https://api.openai.com/v1/chat/completions"
        MAX_RESPONSE_BYTES = 64 * 1024

        def initialize(endpoint: ENDPOINT, api_key: nil)
          @endpoint = endpoint
          @api_key = api_key
        end

        def analyze(request)
          key = @api_key || ENV["RAILVERDICT_AI_API_KEY"] || ENV["OPENAI_API_KEY"]
          unless key && !key.strip.empty?
            return Result.new(analysis: nil, failure: AIFailure.new(code: "authentication_failed", message: "missing API key"))
          end

          uri = URI.parse(@endpoint)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = request.timeouts&.fetch(:connect, 5) || 5
          http.read_timeout = request.timeouts&.fetch(:read, 30) || 30

          body = JSON.generate(
            model: request.model || "gpt-4o-mini",
            messages: [
              { role: "system", content: request.prompt[:system] },
              { role: "user", content: JSON.generate(request.prompt[:untrusted_data]) }
            ],
            response_format: { type: "json_object" },
            max_tokens: 2000
          )

          req = Net::HTTP::Post.new(uri.request_uri)
          req["Content-Type"] = "application/json"
          req["Authorization"] = "Bearer #{key}"
          req.body = body

          response = http.request(req)
          handle_response(response, request)
        rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
          Result.new(analysis: nil, failure: AIFailure.new(code: "timed_out", message: "provider timed out"))
        rescue StandardError => error
          Result.new(analysis: nil, failure: AIFailure.new(code: "provider_unavailable", message: error.message[0, 512]))
        end

        private

        def handle_response(response, request)
          case response.code.to_i
          when 401
            return Result.new(analysis: nil, failure: AIFailure.new(code: "authentication_failed", message: "authentication failed"))
          when 429
            return Result.new(analysis: nil, failure: AIFailure.new(code: "rate_limited", message: "rate limited"))
          when 500..599
            return Result.new(analysis: nil, failure: AIFailure.new(code: "provider_unavailable", message: "provider unavailable: #{response.code}"))
          end

          raw = response.body.to_s
          if raw.bytesize > MAX_RESPONSE_BYTES
            return Result.new(analysis: nil, failure: AIFailure.new(code: "response_invalid", message: "response too large"))
          end

          text = raw.dup.force_encoding(Encoding::UTF_8)
          unless text.valid_encoding?
            return Result.new(analysis: nil, failure: AIFailure.new(code: "response_invalid", message: "invalid encoding"))
          end

          parsed = JSON.parse(text)
          content = extract_content(parsed)
          unless content
            return Result.new(analysis: nil, failure: AIFailure.new(code: "response_invalid", message: "missing content"))
          end

          data = JSON.parse(content)
          data["finding_id"] ||= request.manifest[:finding_id] || request.manifest["finding_id"]
          data["fingerprint"] ||= request.manifest[:fingerprint] || request.manifest["fingerprint"]
          data["provenance"] ||= {}
          data["provenance"]["provider"] ||= "openai_compat"
          data["provenance"]["model"] ||= request.model || "unknown"
          data["provenance"]["prompt_version"] ||= "v1"
          data["provenance"]["created_at"] ||= Time.now.utc.iso8601
          data["schema_version"] ||= "1.0"

          errors = SchemaValidator.validate_ai_analysis(data)
          unless errors.empty?
            return Result.new(analysis: nil, failure: AIFailure.new(code: "schema_invalid", message: errors.first[0, 512]))
          end

          analysis = AIAnalysis.from_hash(data)
          Result.new(analysis: analysis, failure: nil)
        rescue JSON::ParserError => error
          Result.new(analysis: nil, failure: AIFailure.new(code: "response_invalid", message: "invalid JSON: #{error.message[0, 256]}"))
        rescue ArgumentError => error
          Result.new(analysis: nil, failure: AIFailure.new(code: "schema_invalid", message: error.message[0, 512]))
        end

        def extract_content(parsed)
          choices = parsed["choices"]
          return nil unless choices.is_a?(Array) && choices.first

          message = choices.first["message"] || choices.first["delta"]
          return nil unless message

          message["content"]
        end
      end
    end
  end
end
