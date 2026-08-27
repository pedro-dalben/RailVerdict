require "json"
if ARGV.include?("--version")
  puts "brakeman 8.0.6"
  exit 0
end
data = JSON.generate(
  "scan_info" => { "security_warnings" => 0 },
  "warnings" => []
)
out_idx = ARGV.index("-o") || ARGV.index("--output")
out_path = ARGV[out_idx + 1] if out_idx
if out_path
  File.write(out_path, data)
end
exit 3
