# frozen_string_literal: true

require_relative "rails_context/limits"
require_relative "rails_context/confidence"
require_relative "rails_context/classifier"
require_relative "rails_context/constant_inferencer"
require_relative "rails_context/detector"
require_relative "rails_context/schema_parser"
require_relative "rails_context/resolvers/test_candidates"
require_relative "rails_context/resolvers/policy_resolver"
require_relative "rails_context/resolvers/view_resolver"
require_relative "rails_context/resolvers/route_scanner"
require_relative "rails_context/resolvers/route_resolver"
require_relative "rails_context/resolvers/schema_resolver"
require_relative "rails_context/resolvers/association_extractor"
require_relative "rails_context/context"

module RailVerdict
  module RailsContext
  end
end
