if ARGV.include?("--version")
  puts "4.11.0"
else
  require "json"
  data = JSON.generate("schema_version" => "1.0", "runner" => "minitest 4.11.0", "seed" => 0, "tests_total" => 0, "assertions" => 0, "failures" => 0, "errors" => 0, "skips" => 0, "duration_seconds" => 0, "tests" => [])
  out_path = ENV["RAILVERDICT_MINITEST_OUTPUT"]
  if out_path && !out_path.empty?
    File.write(out_path, data)
  else
    puts data
  end
end
