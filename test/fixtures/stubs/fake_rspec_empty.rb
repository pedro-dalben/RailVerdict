require "json"

if ARGV.include?("--version")
  puts "3.13.6"
else
  puts JSON.generate(
    "version" => "3.13.6",
    "examples" => [],
    "summary" => { "duration" => 0.001, "example_count" => 0, "failure_count" => 0, "pending_count" => 0, "errors_outside_of_examples_count" => 0 }
  )
end
