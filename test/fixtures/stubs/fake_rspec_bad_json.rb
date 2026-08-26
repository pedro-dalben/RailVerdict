if ARGV.include?("--version")
  puts "3.13.6"
else
  out_idx = ARGV.index("--out")
  out_path = ARGV[out_idx + 1] if out_idx
  if out_path
    File.write(out_path, "not valid json [[[")
  else
    puts "not valid json [[["
  end
end
