require "json"

if ARGV.include?("--version")
  puts "6.0.6"
else
  puts JSON.generate(
    "schema_version" => "1.0",
    "runner" => "minitest 6.0.6",
    "seed" => 0,
    "tests_total" => 0,
    "assertions" => 0,
    "failures" => 0,
    "errors" => 0,
    "skips" => 0,
    "duration_seconds" => 0.001,
    "tests" => []
  )
end
