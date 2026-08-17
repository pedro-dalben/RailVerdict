# frozen_string_literal: true

module RailVerdict
  module RailsContext
    module Limits
      MAX_FILE_BYTES = 1_048_576
      MAX_FILES = 500
      MAX_RELATED = 20
      MAX_SCHEMA_TABLES = 100
      MAX_COLUMNS_PER_TABLE = 500
      MAX_ASSOCIATIONS = 50
      ROUTES_MAX_BYTES = 524_288
      DATABASE_YML_MAX_BYTES = 16_384
      DEPENDENCIES_MAX = 200
    end
  end
end
