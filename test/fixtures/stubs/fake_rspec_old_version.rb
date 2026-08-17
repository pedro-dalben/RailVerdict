if ARGV.include?("--version")
  puts "3.10.0"
else
  require "json"
  puts JSON.generate("version" => "3.10.0", "examples" => [], "summary" => { "duration" => 0.01, "example_count" => 0, "failure_count" => 0, "pending_count" => 0 })
end
