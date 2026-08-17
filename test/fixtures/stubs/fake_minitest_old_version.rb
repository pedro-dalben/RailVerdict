if ARGV.include?("--version")
  puts "4.11.0"
else
  require "json"
  puts JSON.generate("schema_version" => "1.0", "runner" => "minitest 4.11.0", "seed" => 0, "tests_total" => 0, "assertions" => 0, "failures" => 0, "errors" => 0, "skips" => 0, "duration_seconds" => 0, "tests" => [])
end
