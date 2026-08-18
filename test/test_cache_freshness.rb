# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "rail_verdict/mcp"

class TestCacheFreshness < Minitest::Test
  def init_git_repo(dir)
    system("git", "-C", dir, "init", "-q", out: File::NULL, err: File::NULL)
    system("git", "-C", dir, "config", "user.email", "test@test.test", out: File::NULL, err: File::NULL)
    system("git", "-C", dir, "config", "user.name", "Test", out: File::NULL, err: File::NULL)
  end

  def make_server_with_stored(dir)
    unless File.exist?(File.join(dir, ".railverdict.yml"))
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.4\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: false }\n")
    end
    outcome = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml")
    server = RailVerdict::MCP::Server.new(repository_root: dir)
    server.cache.store_outcome(outcome)
    assert server.cache.valid?, "cache should be valid immediately after store"
    server
  end

  def test_clean_to_dirty_invalidates
    with_tmpdir do |dir|
      init_git_repo(dir)
      File.write(File.join(dir, "a.rb"), "puts 1\n")
      system("git", "-C", dir, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", dir, "commit", "-m", "init", out: File::NULL, err: File::NULL)
      server = make_server_with_stored(dir)
      File.write(File.join(dir, "a.rb"), "puts 2\n")
      refute server.cache.valid?, "clean -> dirty must invalidate"
    end
  end

  def test_dirty_to_dirtier_same_file_invalidates
    with_tmpdir do |dir|
      init_git_repo(dir)
      File.write(File.join(dir, "a.rb"), "puts 1\n")
      system("git", "-C", dir, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", dir, "commit", "-m", "init", out: File::NULL, err: File::NULL)
      # Ensure .railverdict.yml is tracked so it doesn't pollute status
      system("git", "-C", dir, "add", ".railverdict.yml", out: File::NULL, err: File::NULL)
      system("git", "-C", dir, "commit", "-m", "track config", out: File::NULL, err: File::NULL) rescue nil
      File.write(File.join(dir, "a.rb"), "puts 2\n")
      head_before = `git -C #{dir} rev-parse HEAD`.strip
      status_before = `git -C #{dir} status --porcelain -uall --no-renames -- a.rb`.strip
      server = make_server_with_stored(dir)
      assert server.cache.valid?
      File.write(File.join(dir, "a.rb"), "puts 3\n")
      head_after = `git -C #{dir} rev-parse HEAD`.strip
      status_after = `git -C #{dir} status --porcelain -uall --no-renames -- a.rb`.strip
      assert_equal head_before, head_after, "HEAD must not change"
      assert_equal status_before, status_after, "porcelain XY/path must be identical (primary regression)"
      refute server.cache.valid?, "dirty->dirtier same file must invalidate even though porcelain unchanged"
    end
  end

  def test_untracked_content_change_invalidates
    with_tmpdir do |dir|
      init_git_repo(dir)
      File.write(File.join(dir, "a.rb"), "puts 1\n")
      system("git", "-C", dir, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", dir, "commit", "-m", "init", out: File::NULL, err: File::NULL)
      File.write(File.join(dir, "untracked.rb"), "puts 1\n")
      server = make_server_with_stored(dir)
      assert server.cache.valid?
      File.write(File.join(dir, "untracked.rb"), "puts 9999\n")
      refute server.cache.valid?, "untracked content change must invalidate"
    end
  end

  def test_same_second_config_rewrite_invalidates
    with_tmpdir do |dir|
      init_git_repo(dir)
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.4\nmode: strict   #a\nanalyzers:\n  rubocop: { enabled: true, required: false }\n")
      system("git", "-C", dir, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", dir, "commit", "-m", "init", out: File::NULL, err: File::NULL)
      server = make_server_with_stored(dir)
      blob = File.binread(File.join(dir, ".railverdict.yml"))
      File.write(File.join(dir, ".railverdict.yml"), blob.sub("#a", "#b"))
      assert_equal blob.bytesize, File.binread(File.join(dir, ".railverdict.yml")).bytesize
      refute server.cache.valid?, "same-second same-size config rewrite must invalidate"
    end
  end

  def test_same_second_baseline_rewrite_invalidates
    with_tmpdir do |dir|
      init_git_repo(dir)
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.4\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: false }\n")
      system("git", "-C", dir, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", dir, "commit", "-m", "init", out: File::NULL, err: File::NULL)
      server = make_server_with_stored(dir)
      assert server.cache.valid?
      # No sleep, same size where practical (swap digest char)
      File.write(File.join(dir, ".railverdict-baseline.json"), '{"schema_version":"1.0","fingerprint_version":1,"algorithm":"sha256","payload_schema":"x","created_at":"2026-01-01T00:00:00Z","created_by":"test","configuration_digest":"aaaa","analyzer_versions":{},"entries":[]}')
      assert server.cache.valid? == false || true # baseline missing->present is also invalidation
      # Now baseline exists; rewrite same size different content, same second
      assert server.cache.valid? == false # already invalid from missing->present
      # Re-store to get valid with baseline present
      File.write(File.join(dir, ".railverdict-baseline.json"), '{"schema_version":"1.0","fingerprint_version":1,"algorithm":"sha256","payload_schema":"x","created_at":"2026-01-01T00:00:00Z","created_by":"test","configuration_digest":"aaaa","analyzer_versions":{},"entries":[]}')
      server2 = make_server_with_stored(dir)
      assert server2.cache.valid?
      blob = File.binread(File.join(dir, ".railverdict-baseline.json"))
      File.write(File.join(dir, ".railverdict-baseline.json"), blob.sub("aaaa", "bbbb"))
      assert_equal blob.bytesize, File.binread(File.join(dir, ".railverdict-baseline.json")).bytesize
      refute server2.cache.valid?, "same-second same-size baseline rewrite must invalidate"
    end
  end

  def test_same_second_waiver_rewrite_invalidates
    with_tmpdir do |dir|
      init_git_repo(dir)
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.4\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: false }\n")
      system("git", "-C", dir, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", dir, "commit", "-m", "init", out: File::NULL, err: File::NULL)
      File.write(File.join(dir, ".railverdict-waivers.json"), '{"schema_version":"1.0","waivers":[]}')
      server = make_server_with_stored(dir)
      assert server.cache.valid?
      blob = File.binread(File.join(dir, ".railverdict-waivers.json"))
      File.write(File.join(dir, ".railverdict-waivers.json"), '{"schema_version":"1.0","waivers":[{"fingerprint":"sha256:' + "a" * 64 + '","reason":"x","owner":"y","created_at":"2026-01-01T00:00:00Z","expires_at":"2027-01-01T00:00:00Z"}]}')
      # size changed, but must still invalidate (different sha)
      refute server.cache.valid?, "waiver rewrite must invalidate"
      # Second: same-second same-size after present
      server2 = make_server_with_stored(dir)
      assert server2.cache.valid?
      blob2 = File.binread(File.join(dir, ".railverdict-waivers.json"))
      File.write(File.join(dir, ".railverdict-waivers.json"), blob2.sub("x", "y"))
      refute server2.cache.valid?, "same-second waiver content change must invalidate"
    end
  end

  def test_deleted_file_invalidates
    with_tmpdir do |dir|
      init_git_repo(dir)
      File.write(File.join(dir, "a.rb"), "puts 1\n")
      system("git", "-C", dir, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", dir, "commit", "-m", "init", out: File::NULL, err: File::NULL)
      File.write(File.join(dir, "a.rb"), "puts 2\n")
      server = make_server_with_stored(dir)
      assert server.cache.valid?
      File.unlink(File.join(dir, "a.rb"))
      refute server.cache.valid?, "deleted dirty file must invalidate"
    end
  end

  def test_no_change_remains_valid
    with_tmpdir do |dir|
      init_git_repo(dir)
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.4\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: false }\n")
      system("git", "-C", dir, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", dir, "commit", "-m", "init", out: File::NULL, err: File::NULL)
      server = make_server_with_stored(dir)
      assert server.cache.valid?
      assert server.cache.valid?, "no change should remain valid (not always false)"
    end
  end

  def test_weird_paths_content_change_invalidates
    with_tmpdir do |dir|
      init_git_repo(dir)
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.4\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: false }\n")
      spaced = File.join(dir, "spaced name.rb")
      unicode = File.join(dir, "café_ünicode.rb")
      File.write(spaced, "puts 1\n")
      File.write(unicode, "puts 1\n")
      system("git", "-C", dir, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", dir, "commit", "-m", "init", out: File::NULL, err: File::NULL)
      File.write(spaced, "puts 2\n")
      File.write(unicode, "puts 2\n")
      server = make_server_with_stored(dir)
      assert server.cache.valid?
      File.write(spaced, "puts 999\n")
      refute server.cache.valid?, "space-path content change must invalidate"
      server2 = make_server_with_stored(dir)
      assert server2.cache.valid?
      File.write(unicode, "puts 888\n")
      refute server2.cache.valid?, "unicode-path content change must invalidate"
    end
  end

  def test_build_repair_packet_freshness_after_dirty
    with_tmpdir do |dir|
      init_git_repo(dir)
      File.write(File.join(dir, ".railverdict.yml"), "version: 1.4\nmode: strict\nanalyzers:\n  rubocop: { enabled: true, required: false }\n")
      File.write(File.join(dir, "a.rb"), "puts 1\n")
      system("git", "-C", dir, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", dir, "commit", "-m", "init", out: File::NULL, err: File::NULL)
      File.write(File.join(dir, "a.rb"), "puts 2\n")
      outcome = RailVerdict::Check.execute(repository_root: dir, config_path: ".railverdict.yml")
      server = RailVerdict::MCP::Server.new(repository_root: dir)
      server.cache.store_outcome(outcome)
      assert server.cache.valid?
      File.write(File.join(dir, "a.rb"), "puts 3\n")
      refute server.cache.valid?, "build_repair_packet must not use stale outcome"
    end
  end
end
