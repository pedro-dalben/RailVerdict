if ARGV.include?("--version")
  puts "1.88.0"
else
  STDOUT.write("x" * (10 * 1024 * 1024))
  STDOUT.flush
end
