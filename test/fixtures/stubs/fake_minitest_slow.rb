if ARGV.include?("--version")
  out_path = ENV["RAILVERDICT_MINITEST_OUTPUT"]; if out_path && !out_path.empty?; File.write(out_path, "6.0.6"); else; puts "6.0.6"; end
else
  sleep 100
end
