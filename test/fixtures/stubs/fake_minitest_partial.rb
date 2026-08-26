require "json"

if ARGV.include?("--version")
  puts "6.0.6"
else
  full = JSON.generate(
    "schema_version" => "1.0",
    "runner" => "minitest 6.0.6",
    "tests" => [{ "class_name" => "Foo", "method_name" => "test_bar", "status" => "passed" }]
  )
  partial = full[0, full.length / 2]
  out_path = ENV["RAILVERDICT_MINITEST_OUTPUT"]
  if out_path && !out_path.empty?
    File.write(out_path, partial)
  else
    STDOUT.write(partial)
  end
end
