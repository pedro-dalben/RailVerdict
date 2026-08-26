if ARGV.include?("--version")
  out_idx = ARGV.index("--out"); out_path = ARGV[out_idx + 1] if out_idx; if out_path; File.write(out_path, "not a version at all"); else; puts "not a version at all"; end
else
  out_idx = ARGV.index("--out"); out_path = ARGV[out_idx + 1] if out_idx; if out_path; File.write(out_path, "not a version at all"); else; puts "not a version at all"; end
end
