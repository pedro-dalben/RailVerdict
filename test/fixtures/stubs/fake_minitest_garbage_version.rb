if ARGV.include?("--version")
  out_path = ENV["RAILVERDICT_MINITEST_OUTPUT"]; if out_path && !out_path.empty?; File.write(out_path, "not a version at all"); else; puts "not a version at all"; end
else
  out_path = ENV["RAILVERDICT_MINITEST_OUTPUT"]; if out_path && !out_path.empty?; File.write(out_path, "not a version at all"); else; puts "not a version at all"; end
end
