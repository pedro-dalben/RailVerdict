require "json"

if ARGV.include?("--version")
  puts "1.88.0"
else
  puts JSON.generate("files" => [])
end
