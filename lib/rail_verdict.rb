# frozen_string_literal: true

require_relative "rail_verdict/version"
require_relative "rail_verdict/errors"
require_relative "rail_verdict/schema_validator"
require_relative "rail_verdict/strict_yaml"
require_relative "rail_verdict/configuration"
require_relative "rail_verdict/run_context"
require_relative "rail_verdict/process_runner"
require_relative "rail_verdict/check"
require_relative "rail_verdict/init"
require_relative "rail_verdict/doctor"
require_relative "rail_verdict/findings_command"
require_relative "rail_verdict/contracts/finding"
require_relative "rail_verdict/contracts/analyzer_result"
require_relative "rail_verdict/analyzers/rubocop"
require_relative "rail_verdict/contracts/gate_result"
require_relative "rail_verdict/verification/policy"
require_relative "rail_verdict/reporters/console"
require_relative "rail_verdict/reporters/json_reporter"
require_relative "rail_verdict/cli"

module RailVerdict
end
