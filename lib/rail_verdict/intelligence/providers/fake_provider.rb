# frozen_string_literal: true

module RailVerdict
  module Intelligence
    module Providers
      class FakeProvider
        include AIProvider

        attr_reader :last_request, :call_count

        def initialize(results = [])
          @results = results.dup
          @call_count = 0
          @last_request = nil
        end

        def queue(result)
          @results << result
        end

        def analyze(request)
          @call_count += 1
          @last_request = request
          return @results.shift if @results.any?

          Result.new(analysis: nil, failure: AIFailure.new(code: "provider_unavailable", message: "no queued result"))
        end
      end
    end
  end
end
