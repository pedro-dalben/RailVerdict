# frozen_string_literal: true

module RailVerdict
  module Intelligence
    module AIProvider
      Request = Struct.new(:manifest, :prompt, :model, :timeouts, keyword_init: true)
      Result = Struct.new(:analysis, :failure, keyword_init: true)

      def analyze(_request)
        raise NotImplementedError
      end
    end
  end
end
