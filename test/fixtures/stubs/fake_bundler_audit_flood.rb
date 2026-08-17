if ARGV.include?("version")
  puts "bundler-audit 0.9.3"
elsif ARGV.include?("check")
  STDOUT.write("x" * (5 * 1024 * 1024))
else
  exit 1
end
