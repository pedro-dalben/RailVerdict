if ARGV.include?("version")
  puts "bundler-audit 0.9.3"
elsif ARGV.include?("check")
  puts "Downloading ruby-advisory-db ..."
  puts "No JSON here, just logs"
else
  puts "unknown command"
  exit 1
end
