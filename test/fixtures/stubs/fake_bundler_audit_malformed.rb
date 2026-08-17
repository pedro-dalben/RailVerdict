require "json"

if ARGV.include?("version")
  puts "bundler-audit 0.9.3"
elsif ARGV.include?("check")
  puts JSON.generate("results" => "not an array", "version" => "0.9.3")
else
  exit 1
end
