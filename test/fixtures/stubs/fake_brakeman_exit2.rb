if ARGV.include?("--version")
  puts "brakeman 8.0.6"
  exit 0
end
$stderr.puts "Fatal Brakeman error"
exit 2
