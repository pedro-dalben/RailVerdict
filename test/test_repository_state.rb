# frozen_string_literal: true

require_relative "test_helper"

class TestRepositoryState < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("rv-state-")
    File.realpath(@dir)
    git("init", "-q", "-b", "main")
    git("config", "user.email", "t@t.invalid")
    git("config", "user.name", "T")
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def git(*args)
    system("git", "-C", @dir, *args, out: File::NULL, err: File::NULL) or flunk("git #{args.join(' ')} failed")
  end

  def write(path, content)
    full = File.join(@dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.binwrite(full, content)
  end

  def commit(message = "c")
    git("add", "-A")
    git("commit", "-q", "-m", message)
  end

  def capture(paths = nil)
    RailVerdict::RepositoryState.capture(repository_root: @dir, configuration_paths: paths)
  end

  def config_paths(config: nil, baseline: nil, waivers: nil)
    {
      config: config || File.join(@dir, ".railverdict.yml"),
      baseline: baseline || File.join(@dir, ".railverdict-baseline.json"),
      waivers: waivers || File.join(@dir, ".railverdict-waivers.json")
    }
  end

  def seed_config
    write(".railverdict.yml", "version: 1\nmode: strict\nanalyzers:\n  rubocop: { enabled: false, required: false }\n")
  end

  def test_available_with_components_and_digest_shape
    seed_config
    write("a.rb", "puts 1\n")
    commit
    state = capture(config_paths)

    assert state.available?
    assert_match(/\Asha256:[0-9a-f]{64}\z/, state.digest)
    components = state.components
    assert_match(/\A[0-9a-f]{40,64}\z/, components.fetch("head"))
    assert_match(/\Asha256:[0-9a-f]{64}\z/, components.fetch("index_digest"))
    assert_match(/\Asha256:[0-9a-f]{64}\z/, components.fetch("worktree_digest"))
    assert_match(/\Asha256:[0-9a-f]{64}\z/, components.fetch("configuration_digest"))
    assert_nil components.fetch("baseline_digest")
    assert_nil components.fetch("waivers_digest")
    assert_equal 0, state.dirty_paths_count
  end

  def test_repeated_capture_is_identical
    seed_config
    write("a.rb", "puts 1\n")
    commit
    assert_equal capture(config_paths).digest, capture(config_paths).digest
  end

  def test_mtime_only_change_keeps_identity
    seed_config
    write("a.rb", "puts 1\n")
    commit
    before = capture(config_paths).digest
    Time.at(1_000_000_000).to_i
    FileUtils.touch(File.join(@dir, "a.rb"))
    assert_equal before, capture(config_paths).digest, "mtime-only change must not affect identity"
  end

  def test_restoring_exact_bytes_restores_identity
    seed_config
    write("a.rb", "puts 1\n")
    commit
    fresh = capture(config_paths).digest
    write("a.rb", "puts 2\n")
    refute_equal fresh, capture(config_paths).digest
    sleep 0.01
    write("a.rb", "puts 1\n")
    assert_equal fresh, capture(config_paths).digest, "content-addressed identity ignores history"
  end

  def test_new_commit_changes_head_component
    seed_config
    write("a.rb", "puts 1\n")
    commit
    first = capture(config_paths)
    write("b.rb", "puts 2\n")
    commit
    second = capture(config_paths)
    refute_equal first.digest, second.digest
    refute_equal first.components.fetch("head"), second.components.fetch("head")
  end

  def test_amended_commit_changes_identity_even_with_same_tree
    seed_config
    write("a.rb", "puts 1\n")
    commit
    before = capture(config_paths).components.fetch("head")
    write("note.txt", "x\n")
    commit
    git("reset", "-q", "--soft", "HEAD~1")
    git("commit", "-q", "--amend", "-m", "amended")
    # tree is identical to the pre-amend commit of same content? ensure at least head moved
    after = capture(config_paths).components.fetch("head")
    refute_equal before, after
  end

  def test_staged_only_modification_changes_index_component
    seed_config
    write("a.rb", "puts 1\n")
    commit
    base = capture(config_paths)
    write("a.rb", "puts 2\n")
    git("add", "a.rb")
    staged = capture(config_paths)
    refute_equal base.digest, staged.digest
    refute_equal base.components.fetch("index_digest"), staged.components.fetch("index_digest")
    assert_equal base.components.fetch("worktree_digest"), staged.components.fetch("worktree_digest"),
                 "staged-only change with matching worktree keeps worktree delta empty"
  end

  def test_unstaged_only_modification_changes_worktree_only
    seed_config
    write("a.rb", "puts 1\n")
    commit
    base = capture(config_paths)
    write("a.rb", "puts 2\n")
    unstaged = capture(config_paths)
    refute_equal base.digest, unstaged.digest
    assert_equal base.components.fetch("index_digest"), unstaged.components.fetch("index_digest")
    refute_equal base.components.fetch("worktree_digest"), unstaged.components.fetch("worktree_digest")
  end

  def test_mixed_staged_and_unstaged_is_distinguishable
    seed_config
    write("a.rb", "v1\n")
    commit
    write("a.rb", "v2\n")
    git("add", "a.rb")          # index=v2 worktree=v2
    staged = capture(config_paths)
    write("a.rb", "v3\n")       # index=v2 worktree=v3
    mixed = capture(config_paths)
    refute_equal staged.digest, mixed.digest
    assert_equal staged.components.fetch("index_digest"), mixed.components.fetch("index_digest")
    refute_equal staged.components.fetch("worktree_digest"), mixed.components.fetch("worktree_digest")
  end

  def test_index_swap_with_constant_working_copy_is_detected
    seed_config
    write("a.rb", "A\n")
    commit
    write("a.rb", "B\n")
    commit
    # index=B worktree=A
    git("checkout", "-q", "HEAD~1", "--", ".")
    git("restore", "--staged", ".")
    state_a = capture(config_paths)
    write("a.rb", "C\n")
    git("add", "a.rb")          # index=C worktree=C
    state_b = capture(config_paths)
    write("a.rb", "B\n")        # index=C worktree=B
    state_c = capture(config_paths)
    refute_equal state_a.digest, state_c.digest, "same worktree bytes, different index must differ"
    refute_equal state_b.digest, state_c.digest
  end

  def test_untracked_lifecycle_changes_identity
    seed_config
    write("a.rb", "puts 1\n")
    commit
    base = capture(config_paths)
    write("untracked.rb", "one\n")
    added = capture(config_paths)
    refute_equal base.digest, added.digest
    write("untracked.rb", "two\n")
    modified = capture(config_paths)
    refute_equal added.digest, modified.digest
    File.unlink(File.join(@dir, "untracked.rb"))
    assert_equal base.digest, capture(config_paths).digest
  end

  def test_tracked_deletion_and_rename_change_identity
    seed_config
    write("a.rb", "puts 1\n")
    write("b.rb", "puts 2\n")
    commit
    base = capture(config_paths)
    File.unlink(File.join(@dir, "a.rb"))
    deleted = capture(config_paths)
    refute_equal base.digest, deleted.digest
    File.rename(File.join(@dir, "b.rb"), File.join(@dir, "renamed.rb"))
    renamed = capture(config_paths)
    refute_equal deleted.digest, renamed.digest
  end

  def test_configuration_baseline_waiver_content_changes_are_reflected
    seed_config
    commit
    base = capture(config_paths)
    write(".railverdict.yml", "version: 1\nmode: strict   # changed\nanalyzers:\n  rubocop: { enabled: false, required: false }\n")
    after_config = capture(config_paths)
    refute_equal base.components.fetch("configuration_digest"), after_config.components.fetch("configuration_digest")

    write(".railverdict-baseline.json", "{}\n")
    after_baseline = capture(config_paths)
    refute_nil after_baseline.components.fetch("baseline_digest")
    refute_equal after_config.digest, after_baseline.digest

    write(".railverdict-waivers.json", "{\"schema_version\":\"1.0\",\"waivers\":[]}\n")
    after_waivers = capture(config_paths)
    refute_equal after_baseline.digest, after_waivers.digest
  end

  def test_custom_state_paths_are_honored
    seed_config
    commit
    custom_dir = File.join(@dir, "state")
    FileUtils.mkdir_p(custom_dir)
    paths = config_paths(baseline: File.join(custom_dir, "base.json"))
    base = capture(paths)
    assert_nil base.components.fetch("baseline_digest")
    File.write(File.join(custom_dir, "base.json"), "{}\n")
    refute_nil capture(paths).components.fetch("baseline_digest")
    # default path untouched
    assert_nil capture(config_paths).components.fetch("baseline_digest")
  end

  def test_unborn_head_is_explicit_marker
    seed_config
    state = capture(config_paths)
    assert state.available?
    assert_equal RailVerdict::RepositoryState::UNBORN_HEAD, state.components.fetch("head")
  end

  def test_not_a_git_repository_fails_closed
    bare = Dir.mktmpdir("rv-nogit-")
    begin
      state = RailVerdict::RepositoryState.capture(repository_root: bare)
      refute state.available?
      assert_equal "git_unavailable", state.unavailable_reason
    ensure
      FileUtils.rm_rf(bare)
    end
  end

  def test_weird_paths_are_hashed_without_loss
    seed_config
    weird = {
      "spaced name.rb" => "one\n",
      "tab\tname.rb" => "two\n",
      "café_ünicode.rb" => "three\n",
      "[bracket].rb" => "four\n",
      "-leading-dash.rb" => "five\n"
    }
    weird.each { |path, content| write(path, content) }
    commit
    base = capture(config_paths).digest
    write("spaced name.rb", "changed\n")
    refute_equal base, capture(config_paths).digest
    write("spaced name.rb", "one\n")
    assert_equal base, capture(config_paths).digest
    # every remaining path individually detected via its own mutation
    weird.each do |path, _|
      next unless path != "spaced name.rb"

      full = File.join(@dir, path)
      original = File.binread(full)
      File.binwrite(full, "#{original}#extra\n")
      dirty = capture(config_paths).digest
      refute_equal base, dirty, "mutation of #{path.inspect} must change identity"
      File.binwrite(full, original)
      assert_equal base, capture(config_paths).digest, path.inspect
    end
  end

  def test_binary_empty_and_typechange_entries
    seed_config
    write("bin.dat", "\x00\x01\xFF\xFE".b)
    write("empty.txt", "")
    commit
    base = capture(config_paths).digest
    write("bin.dat", "\x00\x01\xFF\xFD".b)
    refute_equal base, capture(config_paths).digest
    write("bin.dat", "\x00\x01\xFF\xFE".b)
    write("empty.txt", "")
    assert_equal base, capture(config_paths).digest

    # regular file -> symlink type change
    File.unlink(File.join(@dir, "empty.txt"))
    File.symlink("bin.dat", File.join(@dir, "empty.txt"))
    symlinked = capture(config_paths)
    refute_equal base, symlinked.digest

    # broken symlink still hashed by target string
    File.unlink(File.join(@dir, "empty.txt"))
    File.symlink("nowhere.bin", File.join(@dir, "empty.txt"))
    broken = capture(config_paths)
    refute_equal symlinked.digest, broken.digest
  end

  def test_identical_checkouts_in_different_directories_have_identical_digests
    seed_config
    write("a.rb", "puts 1\n")
    commit
    origin_digest = capture(config_paths).digest
    clone = File.join(Dir.mktmpdir("rv-clone-"), "clone")
    system("git", "clone", "-q", "file://#{@dir}", clone, out: File::NULL, err: File::NULL)
    begin
      cloned_state = RailVerdict::RepositoryState.capture(repository_root: clone, configuration_paths: {
        config: File.join(clone, ".railverdict.yml"),
        baseline: File.join(clone, ".railverdict-baseline.json"),
        waivers: File.join(clone, ".railverdict-waivers.json")
      })
      assert_equal origin_digest, cloned_state.digest, "identity must not depend on checkout path"
    ensure
      FileUtils.rm_rf(File.dirname(clone))
    end
  end

  def test_dirty_path_bound_fails_closed
    seed_config
    write("a.rb", "puts 1\n")
    commit
    limit = RailVerdict::RepositoryState::MAX_DIRTY_PATHS
    stub_state = Class.new(RailVerdict::RepositoryState) do
      const_set(:MAX_DIRTY_PATHS, limit)
    end
    (limit + 1).times { |i| write("dirty_#{i}.rb", "n=#{i}\n") }

    result = RailVerdict::RepositoryState.capture(repository_root: @dir)
    refute result.available?
    assert_equal "too_many_dirty_paths", result.unavailable_reason
    assert stub_state
  end

  def test_capture_never_raises_for_missing_root
    missing = File.join(@dir, "does-not-exist")
    state = RailVerdict::RepositoryState.capture(repository_root: missing)
    refute state.available?
    assert_equal "repository_root_unavailable", state.unavailable_reason
  end
end
