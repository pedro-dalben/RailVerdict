if ARGV.include?("--version")
  puts "3.13.6"
  exit 0
else
  STDERR.puts "cannot load such file -- spec_helper"
  exit 2
end
