if ARGV.include?("--version")
  puts "6.0.6"
else
  out_path = ENV["RAILVERDICT_MINITEST_OUTPUT"]
  if out_path && !out_path.empty?
    File.write(out_path, "not valid json [[[")
  else
    puts "not valid json [[["
  end
end
