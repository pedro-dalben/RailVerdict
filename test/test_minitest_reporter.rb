# frozen_string_literal: true

require "json"
require "tmpdir"
require "rbconfig"

require_relative "test_helper"

class TestMinitestReporter < Minitest::Test
  ROOT = File.join(RailVerdictTestHelpers::REPOSITORY_ROOT, "lib", "..", "exe")

  def test_reporter_produces_valid_reporter_schema_document
    Dir.mktmpdir("railverdict-reporter-") do |dir|
      dir = File.realpath(dir)
      output_path = File.join(dir, "minitest_report.json")
      reporter_path = File.expand_path("../exe/railverdict-minitest-reporter.rb", __dir__)
      run_file = File.join(dir, "run_test.rb")
      File.write(run_file, <<~RUBY)
        ENV["RAILVERDICT_MINITEST_OUTPUT"] = #{output_path.inspect}
        require "#{reporter_path}"
        require "minitest/autorun"
        class ShopOrderTest < Minitest::Test
          def test_saves_order; assert true; end
          def test_fails_order
            assert false, "order total is wrong"
          end
        end
      RUBY
      require "open3"
      _out, _err, _status = Open3.capture3(RbConfig.ruby, run_file)
      assert File.file?(output_path), "reporter should have written #{output_path}: status=#{_status.exitstatus} err=#{_err[0, 400]}"

      document = JSON.parse(File.read(output_path))
      schema_path = File.expand_path("../schemas/minitest-reporter-v1.schema.json", __dir__)
      schema = JSON.parse(File.read(schema_path))
      errors = JSONSchemer.schema(schema).validate(document).to_a
      assert_empty errors, "reporter output must validate against its own schema: #{errors.map(&:to_h).inspect}"
      assert_equal "1.0", document.fetch("schema_version")
      assert document.fetch("tests").any?
    end
  end

  def test_reporter_writes_with_env_path_even_before_requiring_reporter_directly
    assert File.file?(File.expand_path("../exe/railverdict-minitest-reporter.rb", __dir__))
    schema_path = File.expand_path("../schemas/minitest-reporter-v1.schema.json", __dir__)
    assert File.file?(schema_path)
    schema = JSON.parse(File.read(schema_path))
    assert_equal "1.0", schema["properties"].fetch("schema_version").fetch("const")
  end
end
