if ARGV.include?("version")
  puts "bundler-audit 0.8.0"
elsif ARGV.include?("check")
  require "json"
  puts JSON.generate("results" => [], "version" => "0.8.0")
else
  exit 1
end
