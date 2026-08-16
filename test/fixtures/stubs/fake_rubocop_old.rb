require "json"

if ARGV.include?("--version")
  puts "0.93.0"
else
  puts JSON.generate("files" => [])
end
