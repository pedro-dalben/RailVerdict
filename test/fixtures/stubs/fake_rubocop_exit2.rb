if ARGV.include?("--version")
  puts "1.88.0"
else
  warn "Synthetic RuboCop execution failure"
  exit 2
end
