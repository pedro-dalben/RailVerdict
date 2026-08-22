# frozen_string_literal: true

require "json"

if ARGV.include?("version")
  puts "bundler-audit 0.9.3"
elsif ARGV.include?("check")
  puts JSON.generate("results" => [], "version" => "0.9.3")
  warn "advisory database command failed"
  exit 2
else
  exit 1
end
