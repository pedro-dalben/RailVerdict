require "json"

if ARGV.include?("--version")
  puts "3.13.6"
else
  full = JSON.generate(
    "version" => "3.13.6",
    "examples" => [{ "id" => "./spec/book_spec.rb[1:1]", "full_description" => "Book creates a book", "status" => "failed", "file_path" => "./spec/book_spec.rb", "line_number" => 5, "exception" => { "class" => "RSpec::Expectations::ExpectationNotMetError", "message" => "expected true to be false" } }],
    "summary" => { "duration" => 0.02, "example_count" => 1, "failure_count" => 1, "pending_count" => 0 }
  )
  STDOUT.write(full[0, full.length / 2])
end
