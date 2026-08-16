require "json"

if ARGV.include?("--version")
  puts "1.88.0"
else
  puts JSON.generate(
    "files" => [{
      "path" => "app/models/user.rb",
      "offenses" => [{
        "cop_name" => "Style/Fake",
        "severity" => "apocalyptic",
        "message" => "Synthetic malformed severity",
        "location" => { "start_line" => 1, "last_line" => 1 }
      }]
    }]
  )
end
