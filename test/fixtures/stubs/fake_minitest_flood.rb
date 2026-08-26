if ARGV.include?("--version")
  puts "6.0.6"
else
  out_path = ENV["RAILVERDICT_MINITEST_OUTPUT"]
  if out_path && !out_path.empty?
    File.write(out_path, "x" * (5 * 1024 * 1024))
  else
    STDOUT.write("x" * (5 * 1024 * 1024))
  end
end
