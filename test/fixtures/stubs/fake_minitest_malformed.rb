require "json"

if ARGV.include?("--version")
  puts "6.0.6"
else
  puts JSON.generate(
    "schema_version" => "1.0",
    "runner" => "minitest 6.0.6",
    "seed" => 0,
    "tests_total" => 1,
    "assertions" => 1
  )
end
