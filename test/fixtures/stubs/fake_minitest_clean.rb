require "json"

if ARGV.include?("--version")
  puts "6.0.6"
else
  puts JSON.generate(
    "schema_version" => "1.0",
    "runner" => "minitest 6.0.6",
    "seed" => 42,
    "tests_total" => 2,
    "assertions" => 2,
    "failures" => 0,
    "errors" => 0,
    "skips" => 0,
    "duration_seconds" => 0.012,
    "tests" => [
      { "class_name" => "LibraryTest", "method_name" => "test_borrows_book", "status" => "passed", "time_seconds" => 0.005, "file" => "test/library_test.rb", "line" => 4 },
      { "class_name" => "LibraryTest", "method_name" => "test_returns_book", "status" => "passed", "time_seconds" => 0.007, "file" => "test/library_test.rb", "line" => 10 }
    ]
  )
end
