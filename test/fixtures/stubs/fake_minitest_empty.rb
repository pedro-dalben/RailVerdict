require "json"

if ARGV.include?("--version")
  puts "6.0.6"
else
  data = JSON.generate(
    "schema_version" => "1.0",
    "runner" => "minitest 6.0.6",
    "seed" => 42,
    "tests_total" => 0,
    "assertions" => 0,
    "failures" => 0,
    "errors" => 0,
    "skips" => 0,
    "duration_seconds" => 0.001,
    "tests" => []
  )
  out_path = ENV["RAILVERDICT_MINITEST_OUTPUT"]
  if out_path && !out_path.empty?
    File.write(out_path, data)
  else
    puts data
  end
end
