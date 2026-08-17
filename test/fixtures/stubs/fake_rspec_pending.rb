require "json"

if ARGV.include?("--version")
  puts "3.13.6"
else
  puts JSON.generate(
    "version" => "3.13.6",
    "examples" => [
      { "id" => "./spec/book_spec.rb[1:1]", "description" => "creates a book", "full_description" => "Book creates a book", "status" => "passed", "file_path" => "./spec/book_spec.rb", "line_number" => 5 },
      { "id" => "./spec/book_spec.rb[1:2]", "description" => "is pending", "full_description" => "Book is pending", "status" => "pending", "file_path" => "./spec/book_spec.rb", "line_number" => 12, "pending_message" => "Not yet implemented" }
    ],
    "summary" => { "duration" => 0.02, "example_count" => 2, "failure_count" => 0, "pending_count" => 1, "errors_outside_of_examples_count" => 0 }
  )
end
