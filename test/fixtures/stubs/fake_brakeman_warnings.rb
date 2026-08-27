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
    "security_warnings" => 3,
    "duration" => 0.12,
    "checks_performed" => ["SQL", "SendFile", "CrossSiteScripting"]
  },
  "warnings" => [
    {
      "warning_type" => "SQL Injection",
      "warning_code" => 0,
      "fingerprint" => "1111111111111111111111111111111111111111111111111111111111111111",
      "check_name" => "SQL",
      "message" => "Possible SQL injection in User.where",
      "file" => "app/models/user.rb",
      "line" => 42,
      "link" => "https://brakemanscanner.org/docs/warning_types/sql_injection/",
      "confidence" => "High"
    },
    {
      "warning_type" => "File Access",
      "warning_code" => 16,
      "fingerprint" => "2222222222222222222222222222222222222222222222222222222222222222",
      "check_name" => "SendFile",
      "message" => "Parameter value used in file name",
      "file" => "app/controllers/documents_controller.rb",
      "line" => 109,
      "link" => "https://brakemanscanner.org/docs/warning_types/file_access/",
      "confidence" => "Medium"
    },
    {
      "warning_type" => "Cross-Site Scripting",
      "warning_code" => 2,
      "fingerprint" => "3333333333333333333333333333333333333333333333333333333333333333",
      "check_name" => "LinkToHref",
      "message" => "Unsafe parameter in link_to href",
      "file" => "app/views/home/index.html.erb",
      "line" => 15,
      "link" => "https://brakemanscanner.org/docs/warning_types/link_to_href/",
      "confidence" => "Weak"
    }
  ],
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
exit 3
