if ARGV.include?("--version")
  out_idx = ARGV.index("--out"); out_path = ARGV[out_idx + 1] if out_idx; if out_path; File.write(out_path, "3.13.6"); else; puts "3.13.6"; end
else
  sleep 100
end
