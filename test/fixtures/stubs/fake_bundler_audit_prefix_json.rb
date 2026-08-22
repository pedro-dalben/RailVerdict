require "json"

if ARGV.include?("version")
  puts "bundler-audit 0.9.3"
elsif ARGV.include?("check")
  puts "Downloading ruby-advisory-db ..."
  puts "Updating ruby-advisory-db ..."
  puts JSON.generate("results" => [], "version" => "0.9.3")
else
  puts "unknown command"
  exit 1
end
