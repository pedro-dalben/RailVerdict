if ARGV.include?("--version")
  puts "brakeman 8.0.6"
  exit 0
end
out_idx = ARGV.index("-o") || ARGV.index("--output")
out_path = ARGV[out_idx + 1] if out_idx
if out_path
  File.write(out_path, "A" * (17 * 1024 * 1024))
end
exit 0
