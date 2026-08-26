if ARGV.include?("--version")
  out_path = ENV["RAILVERDICT_MINITEST_OUTPUT"]; if out_path && !out_path.empty?; File.write(out_path, "6.0.6"); else; puts "6.0.6"; end
  exit 0
else
  STDERR.out_path = ENV["RAILVERDICT_MINITEST_OUTPUT"]; if out_path && !out_path.empty?; File.write(out_path, "test suite could not be loaded"); else; puts "test suite could not be loaded"; end
  exit 2
end
