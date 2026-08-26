if ARGV.include?("--version")
  puts "4.7.5"
else
  require "json"
  data = JSON.generate("schema_version" => "1.0", "runner" => "minitest 4.7.5", "tests" => [])
  out_path = ENV["RAILVERDICT_MINITEST_OUTPUT"]
  if out_path && !out_path.empty?
    File.write(out_path, data)
  else
    puts data
  end
end
