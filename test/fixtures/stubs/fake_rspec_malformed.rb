require "json"

if ARGV.include?("--version")
  puts "3.13.6"
else
  puts JSON.generate("version" => "3.13.6", "examples" => "not an array", "summary" => { "duration" => 0.01, "example_count" => 0, "failure_count" => 0, "pending_count" => 0 })
end
