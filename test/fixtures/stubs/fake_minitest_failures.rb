require "json"

if ARGV.include?("--version")
  puts "6.0.6"
else
  puts JSON.generate(
    "schema_version" => "1.0",
    "runner" => "minitest 6.0.6",
    "seed" => 42,
    "tests_total" => 3,
    "assertions" => 3,
    "failures" => 1,
    "errors" => 1,
    "skips" => 1,
    "duration_seconds" => 0.03,
    "tests" => [
      { "class_name" => "BlogPostTest", "method_name" => "test_fails", "status" => "failed", "time_seconds" => 0.01, "file" => "test/models/blog_post_test.rb", "line" => 12, "failure_message" => "Expected true to be false", "failure_class" => "Minitest::Assertion" },
      { "class_name" => "BlogPostTest", "method_name" => "test_errors", "status" => "errored", "time_seconds" => 0.01, "file" => "test/models/blog_post_test.rb", "line" => 20, "failure_message" => "NoMethodError: undefined method", "failure_class" => "NoMethodError" },
      { "class_name" => "BlogPostTest", "method_name" => "test_skipped", "status" => "skipped", "time_seconds" => 0.01, "file" => "test/models/blog_post_test.rb", "line" => 30 }
    ]
  )
end
