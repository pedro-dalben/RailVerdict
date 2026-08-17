# frozen_string_literal: true

module RailVerdict
  module Intelligence
    PROMPT_VERSION = "v1"
  end
end

require_relative "intelligence/ai_analysis"
require_relative "intelligence/ai_failure"
require_relative "intelligence/provider"
