require "json"

if ARGV.include?("version")
  puts "bundler-audit 0.9.3"
elsif ARGV.include?("check")
  puts "Downloading ruby-advisory-db ..."
  puts "Updating ruby-advisory-db ..."
  puts JSON.generate(
    "results" => [
      {
        "gem" => { "name" => "nokogiri", "version" => "1.13.0" },
        "advisory" => { "id" => "CVE-2022-1234", "title" => "Nokogiri XXE vulnerability", "criticality" => "high", "description" => "Nokogiri is vulnerable to XXE" }
      }
    ],
    "version" => "0.9.3"
  )
else
  puts "unknown command"
  exit 1
end
