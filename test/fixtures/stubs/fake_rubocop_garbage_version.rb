require "json"

if ARGV.include?("--version")
  puts "not-a-version"
else
  puts JSON.generate("files" => [])
end
