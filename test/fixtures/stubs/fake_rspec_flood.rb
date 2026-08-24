if ARGV.include?("--version")
  puts "3.13.6"
else
  STDOUT.write("x" * (17 * 1024 * 1024))
end
