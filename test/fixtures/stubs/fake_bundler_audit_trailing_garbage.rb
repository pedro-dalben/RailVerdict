require "json"

if ARGV.include?("version")
  puts "bundler-audit 0.9.3"
elsif ARGV.include?("check")
  puts JSON.generate("results" => [], "version" => "0.9.3") + "\ntrailing garbage that should be rejected"
else
  puts "unknown command"
  exit 1
end
