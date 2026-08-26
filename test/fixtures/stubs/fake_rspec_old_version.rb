if ARGV.include?("--version")
  puts "3.10.0"
else
  require "json"
  data = JSON.generate("version" => "3.10.0", "examples" => [], "summary" => { "duration" => 0.01, "example_count" => 0, "failure_count" => 0, "pending_count" => 0 })
  out_idx = ARGV.index("--out")
  out_path = ARGV[out_idx + 1] if out_idx
  if out_path
    File.write(out_path, data)
  else
    puts data
  end
end
