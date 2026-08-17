# frozen_string_literal: true

require_relative "test_helper"

class TestGemPackaging < Minitest::Test
  def test_gemspec_uses_gemspec_directory_for_discovery
    content = File.read(File.expand_path("../rail_verdict.gemspec", __dir__))
    assert_match(/spec_dir\s*=\s*__dir__/, content)
    assert_match(/File\.join\(spec_dir/, content)
  end

  def test_gemspec_files_are_all_gem_relative_paths
    spec = Gem::Specification.load(File.expand_path("../rail_verdict.gemspec", __dir__))
    spec.files.each do |path|
      refute path.start_with?("/"), "spec.files must be gem-relative, got #{path.inspect}"
    end
  end

  def test_gemspec_includes_required_runtime_files
    spec = Gem::Specification.load(File.expand_path("../rail_verdict.gemspec", __dir__))
    required_patterns = [
      %r{\Alib/rail_verdict\.rb\z},
      %r{\Alib/rail_verdict/mcp/},
      %r{\Alib/rail_verdict/repair/},
      %r{\Alib/rail_verdict/intelligence/},
      %r{\Alib/rail_verdict/rails_context/},
      %r{\Alib/rail_verdict/reporters/},
      %r{\Aschemas/.*\.json\z},
      %r{\Aexe/railverdict\z},
      %r{\Aexe/railverdict-minitest-reporter\.rb\z},
      %r{\AREADME\.md\z},
      %r{\ALICENSE\z},
      %r{\ANOTICE\z}
    ]
    required_patterns.each do |pattern|
      assert spec.files.any? { |file| file.match?(pattern) }, "gemspec must include files matching #{pattern.inspect}"
    end
  end

  def test_gemspec_excludes_non_runtime_paths
    spec = Gem::Specification.load(File.expand_path("../rail_verdict.gemspec", __dir__))
    forbidden = [%r{\A\.planning/}, %r{\A\.commandcode/}, %r{\Atest/}, %r{\Acoverage/}, %r{\Atmp/}]
    forbidden.each do |pattern|
      assert_empty spec.files.select { |file| file.match?(pattern) }, "gemspec must not include #{pattern.inspect}"
    end
  end

  def test_gemspec_executables_match_exe_files
    spec = Gem::Specification.load(File.expand_path("../rail_verdict.gemspec", __dir__))
    assert_includes spec.executables, "railverdict"
    assert_includes spec.executables, "railverdict-minitest-reporter.rb"
  end

  def test_gemspec_has_release_metadata
    spec = Gem::Specification.load(File.expand_path("../rail_verdict.gemspec", __dir__))
    assert_equal "https://railverdict.dev", spec.metadata["homepage_uri"]
    assert_match(%r{\Ahttps://}, spec.metadata["source_code_uri"])
    assert_match(%r{\Ahttps://}, spec.metadata["changelog_uri"])
    assert_equal "true", spec.metadata["rubygems_mfa_required"]
  end

  def test_minitest_reporter_is_executable_on_disk
    reporter = File.expand_path("../exe/railverdict-minitest-reporter.rb", __dir__)
    assert File.file?(reporter)
    assert File.executable?(reporter), "exe/railverdict-minitest-reporter.rb must be executable"
  end

  def test_built_gem_contains_required_files
    gem_path = Dir.glob(File.expand_path("../rail_verdict-*.gem", __dir__)).first
    skip "no built gem found; run gem build rail_verdict.gemspec" unless gem_path && File.file?(gem_path)

    spec = Gem::Specification.load(File.expand_path("../rail_verdict.gemspec", __dir__))
    assert_includes spec.files, "exe/railverdict-minitest-reporter.rb"
    assert_includes spec.files, "lib/rail_verdict/mcp/server.rb"
    assert_includes spec.files, "lib/rail_verdict/repair/packet.rb"
    assert_includes spec.files, "lib/rail_verdict/intelligence/orchestrator.rb"
    assert_includes spec.files, "schemas/repair-packet-v1.schema.json"
  end

  def test_built_gem_excludes_planning_and_tests
    gem_path = Dir.glob(File.expand_path("../rail_verdict-*.gem", __dir__)).first
    skip "no built gem found; run gem build rail_verdict.gemspec" unless gem_path && File.file?(gem_path)

    spec = Gem::Specification.load(File.expand_path("../rail_verdict.gemspec", __dir__))
    assert_empty spec.files.select { |file| file.start_with?(".planning/") || file.start_with?("test/") }
  end
end
