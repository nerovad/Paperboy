# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'open3'
require 'tmpdir'

# The bin scripts that read .env, .env.local or the LockBox clone are run from
# a linked worktree as often as from the shared checkout. Each one has to find
# those files beside the shared checkout, and only bin/checkout-common says
# where that is.
class CheckoutCommonTest < Minitest::Test
  REPO_BIN = File.expand_path('../../bin', __dir__)
  SCRIPTS = %w[checkout-common env-pull gitea-common worktree].freeze

  def setup
    @root = File.realpath(Dir.mktmpdir('checkout-common-test-'))
    @shared = File.join(@root, 'Paperboy')
    @lockbox = File.join(@root, 'LockBox')
    @worktree = File.join(@shared, 'worktrees', '7')
    build_checkout
    build_lockbox("SHARED=one\n")
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def test_the_shared_root_is_worked_out_in_one_place
    owners = Dir[File.join(REPO_BIN, '*')].select do |path|
      File.file?(path) && File.read(path).include?('git-common-dir')
    end

    assert_equal(['checkout-common'], owners.map { |path| File.basename(path) })
  end

  def test_env_pull_check_in_a_worktree_finds_lockbox_beside_the_shared_checkout
    output, status = env_pull('--check')

    assert status.success?, output
    assert_includes output, '--check: .env was not changed'
    refute File.exist?(File.join(@worktree, '.env'))
    refute File.exist?(File.join(@shared, '.env'))
  end

  def test_env_pull_in_a_worktree_writes_the_worktree_env_only
    output, status = env_pull

    assert status.success?, output
    assert_equal "SHARED=one\n", File.read(File.join(@worktree, '.env'))
    refute File.exist?(File.join(@shared, '.env'))
  end

  def test_env_pull_in_a_worktree_reads_the_shared_env_local
    File.write(File.join(@worktree, '.env'), "SHARED=one\nMINE=here\n")
    File.write(File.join(@shared, '.env.local'), "MINE=here\n")

    output, status = env_pull('--check')

    assert status.success?, output
    refute_match(/would lose them/, output)
  end

  def test_env_pull_without_lockbox_says_where_it_looked
    FileUtils.rm_rf(@lockbox)

    output, status = env_pull('--check')

    refute status.success?
    assert_includes output, "no LockBox checkout at #{@shared}/../LockBox"
    assert_includes output, "beside the shared checkout #{@shared}"
  end

  def test_gitea_settings_in_a_worktree_come_from_the_shared_checkout
    File.write(File.join(@shared, '.env.local'), "GITEA_TOKEN=shared-token\n")

    assert_equal 'shared-token', gitea_token
  end

  def test_gitea_settings_prefer_the_worktrees_own_copy
    File.write(File.join(@shared, '.env.local'), "GITEA_TOKEN=shared-token\n")
    File.write(File.join(@worktree, '.env.local'), "GITEA_TOKEN=own-token\n")

    assert_equal 'own-token', gitea_token
  end

  def test_worktree_context_in_a_worktree_names_the_shared_checkout
    output, status = Open3.capture2e(File.join(@worktree, 'bin/worktree'), 'context', chdir: @worktree)

    assert status.success?, output
    assert_includes output, "Repository: #{@shared}\n"
    assert_includes output, "Current worktree: #{@worktree}\n"
  end

  private

  def build_checkout
    FileUtils.mkdir_p(File.join(@shared, 'bin'))
    SCRIPTS.each do |name|
      FileUtils.cp(File.join(REPO_BIN, name), File.join(@shared, 'bin', name))
    end
    git(@shared, 'init', '-q', '-b', 'master')
    git(@shared, 'config', 'user.email', 'test@example.com')
    git(@shared, 'config', 'user.name', 'Paperboy Test')
    git(@shared, 'add', 'bin')
    git(@shared, 'commit', '-q', '-m', 'Scripts')
    git(@shared, 'worktree', 'add', '-q', '-b', 'issue/7-first-worktree', @worktree, 'HEAD')
  end

  def build_lockbox(contents)
    FileUtils.mkdir_p(@lockbox)
    git(@lockbox, 'init', '-q')
    File.write(File.join(@lockbox, 'Paperboy.env'), contents)
  end

  def git(directory, *args)
    output, status = Open3.capture2e('git', '-C', directory, *args)
    assert status.success?, output
  end

  def env_pull(*args)
    Open3.capture2e({ 'LOCKBOX_DIR' => nil }, File.join(@worktree, 'bin/env-pull'), *args, chdir: @worktree)
  end

  def gitea_token
    script = 'source bin/gitea-common; gitea_load_config; printf %s "$GITEA_TOKEN"'
    output, status = Open3.capture2e({ 'GITEA_ENV_FILE' => nil, 'GITEA_TOKEN' => nil },
                                     'bash', '-c', script, chdir: @worktree)
    assert status.success?, output
    output
  end
end
