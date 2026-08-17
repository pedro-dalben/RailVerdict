require "json"

if ARGV.include?("--version")
  puts "6.0.6"
else
  full = JSON.generate(
    "schema_version" => "1.0",
    "runner" => "minitest 6.0.6",
    "seed" => 0,
    "tests_total" => 1,
    "assertions" => 1,
    "failures" => 1,
    "errors" => 0,
    "skips" => 0,
    "duration_seconds" => 0.01,
    "tests" => [
      { "class_name" => "BlogPostTest", "method_name" => "test_fails", "status" => "failed", "time_seconds" => 0.01, "file" => "test/blog_post_test.rb", "line" => 5, "failure_message" => "Expected true to be false", "failure_class" => "Minitest::Assertion" }
    ]
  )
  STDOUT.write(full[0, full.length / 2])
end
