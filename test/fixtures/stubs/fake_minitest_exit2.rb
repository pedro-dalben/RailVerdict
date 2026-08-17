if ARGV.include?("--version")
  puts "6.0.6"
  exit 0
else
  STDERR.puts "test suite could not be loaded"
  exit 2
end
