if ARGV.include?("--version")
  puts "3.13.6"
else
  STDOUT.write("x" * (5 * 1024 * 1024))
end
