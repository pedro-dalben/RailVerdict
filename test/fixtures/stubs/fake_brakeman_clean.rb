require "json"

if ARGV.include?("--version")
  puts "brakeman 8.0.6"
  exit 0
end

data = JSON.generate(
  "scan_info" => {
    "app_path" => "/fake/app",
    "rails_version" => "8.0.1",
    "brakeman_version" => "8.0.6",
    "ruby_version" => "3.4.0",
    "security_warnings" => 0,
    "duration" => 0.05,
    "checks_performed" => ["SQL", "SendFile", "CrossSiteScripting"]
  },
  "warnings" => [],
  "errors" => [],
  "obsolete" => []
)

out_idx = ARGV.index("-o") || ARGV.index("--output")
out_path = ARGV[out_idx + 1] if out_idx
if out_path
  File.write(out_path, data)
else
  puts data
end
exit 0
