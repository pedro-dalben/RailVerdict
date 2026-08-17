# frozen_string_literal: true

require_relative "test_helper"

class TestChangedLineEvaluator < Minitest::Test
  def coverage_doc(files)
    { "files" => files }
  end

  def test_all_covered_returns_hundred_percent
    doc = coverage_doc([
      { "filename" => "app/models/book.rb", "coverage" => { "lines" => [1, 1, nil, 1] } }
    ])
    result = RailVerdict::Coverage::ChangedLineEvaluator.evaluate(
      coverage_document: doc,
      line_set: { "app/models/book.rb" => [1, 2, 4] }
    )
    assert_equal 3, result.fetch("executable_lines")
    assert_equal 3, result.fetch("covered_lines")
    assert_equal 100.0, result.fetch("percent")
    assert_empty result.fetch("missing_lines")
  end

  def test_none_covered_returns_zero_percent
    doc = coverage_doc([
      { "filename" => "app/models/book.rb", "coverage" => { "lines" => [0, 0, nil, 0] } }
    ])
    result = RailVerdict::Coverage::ChangedLineEvaluator.evaluate(
      coverage_document: doc,
      line_set: { "app/models/book.rb" => [1, 2, 4] }
    )
    assert_equal 3, result.fetch("executable_lines")
    assert_equal 0, result.fetch("covered_lines")
    assert_equal 0.0, result.fetch("percent")
    assert_equal 3, result.fetch("missing_lines").length
  end

  def test_mixed_returns_correct_percent_and_missing
    doc = coverage_doc([
      { "filename" => "app/models/book.rb", "coverage" => { "lines" => [1, 0, nil, 1] } },
      { "filename" => "app/models/user.rb", "coverage" => { "lines" => [0, 1] } }
    ])
    result = RailVerdict::Coverage::ChangedLineEvaluator.evaluate(
      coverage_document: doc,
      line_set: { "app/models/book.rb" => [1, 2, 4], "app/models/user.rb" => [1, 2] }
    )
    assert_equal 5, result.fetch("executable_lines")
    assert_equal 3, result.fetch("covered_lines")
    assert_equal 60.0, result.fetch("percent")
    assert_equal [["app/models/book.rb", 2], ["app/models/user.rb", 1]], result.fetch("missing_lines")
  end

  def test_path_not_in_line_set_is_ignored
    doc = coverage_doc([
      { "filename" => "app/models/book.rb", "coverage" => { "lines" => [1, 1] } },
      { "filename" => "app/models/user.rb", "coverage" => { "lines" => [0, 0] } }
    ])
    result = RailVerdict::Coverage::ChangedLineEvaluator.evaluate(
      coverage_document: doc,
      line_set: { "app/models/book.rb" => [1] }
    )
    assert_equal 1, result.fetch("executable_lines")
    assert_equal 1, result.fetch("covered_lines")
  end

  def test_path_in_line_set_but_not_in_coverage_is_missing
    doc = coverage_doc([])
    result = RailVerdict::Coverage::ChangedLineEvaluator.evaluate(
      coverage_document: doc,
      line_set: { "app/models/missing.rb" => [1, 2] }
    )
    assert_equal 2, result.fetch("executable_lines")
    assert_equal 0, result.fetch("covered_lines")
    assert_equal 2, result.fetch("missing_lines").length
  end

  def test_nil_lines_are_non_executable_and_skipped
    doc = coverage_doc([
      { "filename" => "app/models/book.rb", "coverage" => { "lines" => [1, nil, nil, 0] } }
    ])
    result = RailVerdict::Coverage::ChangedLineEvaluator.evaluate(
      coverage_document: doc,
      line_set: { "app/models/book.rb" => [2, 3] }
    )
    assert_equal 0, result.fetch("executable_lines")
    assert_equal 100.0, result.fetch("percent")
    assert_empty result.fetch("missing_lines")
  end

  def test_empty_line_set_returns_hundred_percent
    doc = coverage_doc([
      { "filename" => "app/models/book.rb", "coverage" => { "lines" => [1, 0] } }
    ])
    result = RailVerdict::Coverage::ChangedLineEvaluator.evaluate(
      coverage_document: doc,
      line_set: {}
    )
    assert_equal 0, result.fetch("executable_lines")
    assert_equal 100.0, result.fetch("percent")
    assert_empty result.fetch("missing_lines")
  end

  def test_missing_lines_sorted_and_deterministic
    doc = coverage_doc([
      { "filename" => "app/models/user.rb", "coverage" => { "lines" => [0, 0] } },
      { "filename" => "app/models/book.rb", "coverage" => { "lines" => [0, 0] } }
    ])
    line_set = { "app/models/user.rb" => [2, 1], "app/models/book.rb" => [2, 1] }
    first = RailVerdict::Coverage::ChangedLineEvaluator.evaluate(coverage_document: doc, line_set: line_set)
    second = RailVerdict::Coverage::ChangedLineEvaluator.evaluate(coverage_document: doc, line_set: line_set)
    assert_equal first.fetch("missing_lines"), second.fetch("missing_lines")
    assert_equal first, second
  end

  def test_percent_rounding
    doc = coverage_doc([
      { "filename" => "app/models/book.rb", "coverage" => { "lines" => [1, 1, 0] } }
    ])
    result = RailVerdict::Coverage::ChangedLineEvaluator.evaluate(
      coverage_document: doc,
      line_set: { "app/models/book.rb" => [1, 2, 3] }
    )
    assert_equal 66.67, result.fetch("percent")
  end
end
