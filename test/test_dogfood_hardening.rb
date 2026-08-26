# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "fileutils"
require "json"

class TestDogfoodHardening < Minitest::Test
  # Helpers
  def with_tmp_yml(content)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), content)
      yield dir
    end
  end

  def simplecov_fresh(dir, json)
    full = File.join(dir, "coverage/coverage.json")
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, JSON.generate(json))
    FileUtils.touch(full, mtime: Time.now)
  end

  # IRV-001 — native SimpleCov
  def test_coverage_v1_still_valid
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"version"=>"1.0","timestamp"=>9999999999,"files"=>[{"filename"=>"a/b.rb","coverage"=>{"lines"=>[1,0,nil,1]}}]}
      simplecov_fresh(dir, j)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal "succeeded", r.execution_status
      assert_equal 2, r.evidence_summary["covered_lines"]
    end
  end

  def test_native_simplecov_valid
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"meta"=>{"simplecov_version"=>"1.1.1"},"coverage"=>{"app/a.rb"=>{"lines"=>[1,0,nil,1]}},"groups"=>{}}
      simplecov_fresh(dir, j)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal "succeeded", r.execution_status
      assert_equal "1.1.1", r.tool_version
    end
  end

  def test_native_simplecov_unsupported_version
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"meta"=>{"simplecov_version"=>"0.22.0"},"coverage"=>{"app/a.rb"=>{"lines"=>[1,0,nil,1]}},"groups"=>{}}
      simplecov_fresh(dir, j)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal "unsupported", r.execution_status
    end
  end

  def test_native_multiple_files
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"meta"=>{"simplecov_version"=>"1.0.0"},"coverage"=>{"a/b.rb"=>{"lines"=>[1,0]},"c/d.rb"=>{"lines"=>[1,1]}},"groups"=>{}}
      simplecov_fresh(dir, j)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal 3, r.evidence_summary["covered_lines"]
      assert_equal 4, r.evidence_summary["executable_lines"]
    end
  end

  def test_native_nil_lines
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"meta"=>{"simplecov_version"=>"1.0.0"},"coverage"=>{"a/b.rb"=>{"lines"=>[nil,nil,nil]}},"groups"=>{}}
      simplecov_fresh(dir, j)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal 0, r.evidence_summary["executable_lines"]
      assert_equal 100.0, r.evidence_summary["percent"]
    end
  end

  def test_native_zero_hit
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"meta"=>{"simplecov_version"=>"1.0.0"},"coverage"=>{"a/b.rb"=>{"lines"=>[0]}},"groups"=>{}}
      simplecov_fresh(dir, j)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal 1, r.evidence_summary["executable_lines"]
      assert_equal 0, r.evidence_summary["covered_lines"]
    end
  end

  def test_native_hit
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"meta"=>{"simplecov_version"=>"1.0.0"},"coverage"=>{"a/b.rb"=>{"lines"=>[2]}},"groups"=>{}}
      simplecov_fresh(dir, j)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal 1, r.evidence_summary["covered_lines"]
    end
  end

  def test_native_empty_file
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"meta"=>{"simplecov_version"=>"1.0.0"},"coverage"=>{"a/b.rb"=>{"lines"=>[]}},"groups"=>{}}
      simplecov_fresh(dir, j)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal "succeeded", r.execution_status
    end
  end

  def test_native_path_normalization
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"meta"=>{"simplecov_version"=>"1.0.0"},"coverage"=>{"./a/b.rb"=>{"lines"=>[1]}},"groups"=>{}}
      simplecov_fresh(dir, j)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal "a/b.rb", r.evidence_summary["files"].first["filename"]
    end
  end

  def test_native_malformed_json
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      full = File.join(dir, "coverage/coverage.json")
      FileUtils.mkdir_p(File.dirname(full))
      File.binwrite(full, "not json")
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal "parse_failed", r.execution_status
    end
  end

  def test_native_malformed_doc
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"meta"=>{"simplecov_version"=>"1.0.0"},"coverage"=>{"a/b.rb"=>{"lines"=>"bad"}},"groups"=>{}}
      simplecov_fresh(dir, j)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal "malformed", r.execution_status
    end
  end

  def test_native_unsupported_shape
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"foo"=>"bar"}
      simplecov_fresh(dir, j)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_includes %w[unsupported malformed], r.execution_status
    end
  end

  def test_native_stale_and_fresh
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"meta"=>{"simplecov_version"=>"1.0.0"},"coverage"=>{"a/b.rb"=>{"lines"=>[1]}},"groups"=>{}}
      full = File.join(dir, "coverage/coverage.json")
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, JSON.generate(j))
      FileUtils.touch(full, mtime: Time.now - 200_000)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert r.evidence_summary["stale"]
      FileUtils.touch(full, mtime: Time.now)
      r2,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      refute r2.evidence_summary["stale"]
    end
  end

  def test_native_oversized
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      full = File.join(dir, "coverage/coverage.json")
      FileUtils.mkdir_p(File.dirname(full))
      File.binwrite(full, "a" * (8 * 1024 * 1024 + 1))
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal "truncated", r.execution_status
    end
  end

  def test_native_deterministic
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"meta"=>{"simplecov_version"=>"1.0.0"},"coverage"=>{"b.rb"=>{"lines"=>[1]},"a.rb"=>{"lines"=>[1]}},"groups"=>{}}
      simplecov_fresh(dir, j)
      r1,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      r2,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      assert_equal r1.evidence_summary["files"], r2.evidence_summary["files"]
    end
  end

  def test_native_changed_line_coverage
    with_tmp_yml("version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  simplecov:\n    enabled: true\n    required: true\n") do |dir|
      j = {"meta"=>{"simplecov_version"=>"1.0.0"},"coverage"=>{"app/b.rb"=>{"lines"=>[1,0,1]}},"groups"=>{}}
      simplecov_fresh(dir, j)
      r,_ = RailVerdict::Analyzers::SimpleCov.new.run(dir)
      doc = r.evidence_summary["_coverage_document"]
      ev = RailVerdict::Coverage::ChangedLineEvaluator.evaluate(coverage_document: doc, line_set: {"app/b.rb"=>[2]})
      assert_equal 0, ev["covered_lines"]
    end
  end

  # IRV-002
  def test_finding_message_fallbacks
    %w[rubocop rspec minitest bundler_audit].each do |analyzer|
      assert_equal "#{analyzer} reported a finding without a message", RailVerdict::Analyzers::Shared.normalize_finding_message(analyzer, nil)
      assert_equal "#{analyzer} reported a finding without a message", RailVerdict::Analyzers::Shared.normalize_finding_message(analyzer, "")
      assert_equal "#{analyzer} reported a finding without a message", RailVerdict::Analyzers::Shared.normalize_finding_message(analyzer, "   ")
      assert_equal "#{analyzer} reported a finding without a message", RailVerdict::Analyzers::Shared.normalize_finding_message(analyzer, "\t\n")
    end
  end

  def test_invalid_utf8_normalized
    msg = RailVerdict::Analyzers::Shared.normalize_finding_message("rubocop", "\xFF\xFE".dup.force_encoding(Encoding::ASCII_8BIT))
    assert msg.valid_encoding?
    refute_empty msg
  end

  def test_ansi_stripped
    msg = RailVerdict::Analyzers::Shared.normalize_finding_message("rubocop", "\e[31mhello\e[0m")
    assert_equal "hello", msg
  end

  def test_extremely_large_truncated
    msg = RailVerdict::Analyzers::Shared.normalize_finding_message("rubocop", "a" * 10_000)
    assert msg.bytesize <= 4096
  end

  def test_check_does_not_crash_on_empty_message_rubocop
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      # Fake rubocop that returns empty messages via stub
      stub = File.join(dir, "fake_rubocop.rb")
      File.write(stub, <<~RB)
        require "json"
        if ARGV.include?("--version")
          puts "1.89.0"
        else
          puts JSON.generate({"files"=>[{"path"=>"a/b.rb","offenses"=>[{"cop_name"=>"A/B","severity"=>"warning","message"=>"  ","location"=>{"start_line"=>1,"last_line"=>1}}]}]})
        end
      RB
      adapter = RailVerdict::Analyzers::RuboCop.new(command_resolver: ->(_){ {executable: RbConfig.ruby, args_prefix: [stub]} })
      result, findings = adapter.run(dir)
      assert_equal "succeeded", result.execution_status
      assert_equal "rubocop reported a finding without a message", findings.first.message
    end
  end

  def test_cli_emits_json_on_empty_message
    Dir.mktmpdir do |dir|
      # Use Check boundary with stub that raises ArgumentError inside normalization without Shared
      # Instead simulate via Check rescue: create adapter that raises
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      stub = File.join(dir, "fake_rspec.rb")
      File.write(stub, <<~RB)
        puts "3.13.6" if ARGV.include?("--version")
        require "json"
        out = ARGV[ARGV.index("--out") + 1] rescue nil
        data = JSON.generate({"summary"=>{"duration"=>1,"failure_count"=>1,"pending_count"=>0},"examples"=>[{"id"=>"a","status"=>"failed","file_path"=>"spec/a_spec.rb","description"=>"","full_description"=>"","exception"=>{"message"=>""}}],"version"=>"3.13.6"})
        if out; File.write(out, data); else; puts data; end unless ARGV.include?("--version")
        exit 1 unless ARGV.include?("--version")
      RB
      adapter = RailVerdict::Analyzers::RSpec.new(command_resolver: ->(_){ {executable: RbConfig.ruby, args_prefix: [stub]} })
      probe = adapter.probe(dir, runner: RailVerdict::ProcessRunner)
      # Ensure no exception escapes
      begin
        adapter.run(dir, probe_result: probe)
      rescue StandardError => e
        flunk "should not raise #{e.class}: #{e.message}"
      end
    end
  end

  # IRV-003
  def test_analyzer_unknown_version
    r = RailVerdict::AnalyzerResult.new(analyzer: "rubocop", invocation: {"executable"=>"rubocop","argv"=>[]}, execution_status: "succeeded", finding_ids: [], tool_version: nil)
    assert_nil r.tool_version
    assert_equal "unknown", RailVerdict::Analyzers::Shared.canonical_tool_version(nil)
  end

  def test_baseline_create_unknown
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      cfg = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      f = RailVerdict::Finding.new(fingerprint: RailVerdict::Fingerprint.hexdigest(analyzer:"rubocop", rule_id:"A/B", path:"a/b.rb", message:"m"), origin:"deterministic", analyzer:"rubocop", rule_id:"A/B", category:"style", severity:"low", confidence:"high", state:"observed", evidence_ref:"native:rubocop:abc", location:{"path"=>"a/b.rb"}, message:"m")
      b = RailVerdict::Baseline.create(findings:[f], configuration: cfg, analyzer_versions: {"rubocop"=>nil}, clock: Time.utc(2026,1,1))
      assert_equal "unknown", b.to_h["analyzer_versions"]["rubocop"]
      path = File.join(dir, ".railverdict-baseline.json")
      RailVerdict::Baseline.write(path:path, baseline:b, force:true)
      loaded = RailVerdict::Baseline.read(path)
      assert_equal "unknown", loaded.to_h["analyzer_versions"]["rubocop"]
      # digest determinism
      b2 = RailVerdict::Baseline.create(findings:[f], configuration: cfg, analyzer_versions: {"rubocop"=>nil}, clock: Time.utc(2026,1,1))
      assert_equal b.to_h["analyzer_versions"], b2.to_h["analyzer_versions"]
    end
  end

  def test_baseline_old_compatibility
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: true\n    required: true\n")
      cfg = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      f = RailVerdict::Finding.new(fingerprint: RailVerdict::Fingerprint.hexdigest(analyzer:"rubocop", rule_id:"A/B", path:"a/b.rb", message:"m"), origin:"deterministic", analyzer:"rubocop", rule_id:"A/B", category:"style", severity:"low", confidence:"high", state:"observed", evidence_ref:"native:rubocop:abc", location:{"path"=>"a/b.rb"}, message:"m")
      b = RailVerdict::Baseline.create(findings:[f], configuration: cfg, analyzer_versions: {"rubocop"=>"1.89.0"}, clock: Time.utc(2026,1,1))
      path = File.join(dir, ".railverdict-baseline.json")
      RailVerdict::Baseline.write(path:path, baseline:b, force:true)
      loaded = RailVerdict::Baseline.read(path)
      assert_equal "1.89.0", loaded.to_h["analyzer_versions"]["rubocop"]
    end
  end

  # IRV-004
  def test_rspec_large_valid_json
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  rspec:\n    enabled: true\n    required: true\n")
      # generate large RSpec JSON ~5MiB but within 16MiB limit
      large_examples = (1..8000).map do |i|
        {"id"=>"spec/a_spec.rb[1:#{i}]","status"=>"passed","file_path"=>"spec/a_spec.rb","full_description"=>"example #{i}","description"=>"example #{i}","line_number"=>i}
      end
      json = {"summary"=>{"duration"=>10,"failure_count"=>0,"pending_count"=>0},"examples"=>large_examples,"version"=>"3.13.6"}
      stub = File.join(dir, "fake_large.rb")
      File.write(stub, "if ARGV.include?(\"--version\")\n puts \"3.13.6\"\nelse\n require \"json\"; out = ARGV[ARGV.index(\"--out\") + 1] rescue nil; data = JSON.generate(#{json.inspect}); if out; File.write(out, data); else; puts data; end\nend\n")
      adapter = RailVerdict::Analyzers::RSpec.new(command_resolver: ->(_){ {executable: RbConfig.ruby, args_prefix: [stub]} })
      result, findings = adapter.run(dir)
      assert_equal "succeeded", result.execution_status
      assert_equal 8000, result.evidence_summary["tests_total"]
    end
  end

  def test_truncation_produces_controlled_incomplete
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  rspec:\n    enabled: true\n    required: true\n")
      stub = File.join(dir, "fake_flood.rb")
      File.write(stub, "if ARGV.include?(\"--version\"); puts \"3.13.6\"; else; STDOUT.write(\"x\"*(17*1024*1024)); end")
      adapter = RailVerdict::Analyzers::RSpec.new(command_resolver: ->(_){ {executable: RbConfig.ruby, args_prefix: [stub]} })
      result,_ = adapter.run(dir)
      assert_equal "truncated", result.execution_status
      cfg = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      gate = RailVerdict::Verification::Policy.evaluate(configuration: cfg, analyzer_results:[result], findings:[])
      assert_equal "incomplete", gate.completion_status
      assert_equal "INCOMPLETE", gate.gate
    end
  end

  def test_cross_defect_large_truncated_empty_message
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.1\nmode: strict\nanalyzers:\n  rubocop:\n    enabled: false\n    required: false\n  rspec:\n    enabled: true\n    required: true\n")
      # Combined: truncated output that would have empty message if parsed, but truncation prevents parsing
      stub = File.join(dir, "fake_cross.rb")
      File.write(stub, "if ARGV.include?(\"--version\"); puts \"3.13.6\"; else; STDOUT.write(\"x\"*(17*1024*1024)); end")
      adapter = RailVerdict::Analyzers::RSpec.new(command_resolver: ->(_){ {executable: RbConfig.ruby, args_prefix: [stub]} })
      result, findings = adapter.run(dir)
      assert_equal "truncated", result.execution_status
      assert_empty findings
      # Check gate does not crash and is incomplete not pass
      cfg = RailVerdict::Configuration.load(File.join(dir, ".railverdict.yml"))
      gate = RailVerdict::Verification::Policy.evaluate(configuration: cfg, analyzer_results:[result], findings:findings)
      assert_equal "incomplete", gate.completion_status
      refute_equal "PASS", gate.gate
    end
  end
end
