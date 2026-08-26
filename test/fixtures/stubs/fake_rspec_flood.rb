if ARGV.include?("--version")
  puts "3.13.6"
else
  out_idx = ARGV.index("--out")
  out_path = ARGV[out_idx + 1] if out_idx
  if out_path
    File.write(out_path, "x" * (17 * 1024 * 1024))
  else
    STDOUT.write("x" * (17 * 1024 * 1024))
  end
end
