# frozen_string_literal: true

require 'minitest/autorun'
require 'fileutils'
require 'open3'
require 'tmpdir'

class WorktreeScriptTest < Minitest::Test
  SCRIPT = File.expand_path('../../bin/worktree', __dir__)

  def setup
    @repository = Dir.mktmpdir('paperboy-worktree-test-')
    run_git('init', '-b', 'master')
    run_git('config', 'user.email', 'test@example.com')
    run_git('config', 'user.name', 'Paperboy Test')
    File.write(File.join(@repository, 'README'), "test\n")
    run_git('add', 'README')
    run_git('commit', '-m', 'Initial commit')
    run_git('remote', 'add', 'origin', 'https://example.test/paperboy.git')
    FileUtils.mkdir_p(File.join(@repository, 'worktrees'))
    run_git('worktree', 'add', '-b', 'issue/7-first-worktree',
            File.join(@repository, 'worktrees', '7'), 'HEAD')
  end

  def teardown
    FileUtils.rm_rf(@repository)
  end

  def test_context_reports_the_linked_worktree_and_issue
    output = run_script('context', chdir: File.join(@repository, 'worktrees', '7'))

    assert_includes output, "Repository: #{@repository}\n"
    assert_includes output, "Current worktree: #{@repository}/worktrees/7\n"
    assert_includes output, "Branch: issue/7-first-worktree\n"
    assert_includes output, "Issue: 7\n"
    assert_includes output, "Session target: linked worktree\n"
  end

  def test_create_from_a_linked_worktree_uses_the_shared_checkout
    output = run_script('create', 'issue/8-second-worktree',
                        chdir: File.join(@repository, 'worktrees', '7'))

    expected_path = File.join(@repository, 'worktrees', '8')
    assert_equal "#{expected_path}\n", output
    assert Dir.exist?(expected_path)
    refute Dir.exist?(File.join(@repository, 'worktrees', '7', 'worktrees', '8'))
  end

  def test_create_from_an_origin_tracking_branch
    run_git('commit', '--allow-empty', '-m', 'Remote issue commit')
    remote_commit = run_git('rev-parse', 'HEAD').strip
    run_git('update-ref', 'refs/remotes/origin/issue/9-remote-worktree', remote_commit)

    output = run_script('create', 'issue/9-remote-worktree')

    expected_path = File.join(@repository, 'worktrees', '9')
    assert_equal "#{expected_path}\n", output
    assert_equal 'issue/9-remote-worktree',
                 run_git('-C', expected_path, 'symbolic-ref', '--short', 'HEAD').strip
    assert_equal('origin/issue/9-remote-worktree',
                 run_git('config', '--get',
                         'branch.issue/9-remote-worktree.remote').strip.then do |remote|
                           "#{remote}/#{run_git('config', '--get',
                                                'branch.issue/9-remote-worktree.merge').strip.delete_prefix('refs/heads/')}"
                         end)
  end

  def test_open_by_issue_number_finds_an_origin_tracking_branch
    run_git('commit', '--allow-empty', '-m', 'Remote issue commit')
    remote_commit = run_git('rev-parse', 'HEAD').strip
    run_git('update-ref', 'refs/remotes/origin/issue/10-remote-worktree', remote_commit)

    output = run_script('10')

    expected_path = File.join(@repository, 'worktrees', '10')
    assert_equal "#{expected_path}\n", output
    assert_equal 'issue/10-remote-worktree',
                 run_git('-C', expected_path, 'symbolic-ref', '--short', 'HEAD').strip
  end

  def test_create_copies_env_from_the_common_checkout
    File.write(File.join(@repository, '.env'), "PAPERBOY_TEST_VALUE=from-root\n")

    output = run_script('create', 'issue/11-env-worktree')

    expected_path = File.join(@repository, 'worktrees', '11')
    assert_equal "#{expected_path}\n", output
    assert_equal "PAPERBOY_TEST_VALUE=from-root\n",
                 File.read(File.join(expected_path, '.env'))
  end

  private

  def run_git(*arguments)
    stdout, stderr, status = Open3.capture3('git', '-C', @repository, *arguments)
    assert status.success?, "git #{arguments.join(' ')} failed: #{stderr}"
    stdout
  end

  def run_script(*arguments, chdir: @repository)
    stdout, stderr, status = Open3.capture3(SCRIPT, *arguments, chdir: chdir)
    assert status.success?, "#{SCRIPT} #{arguments.join(' ')} failed: #{stderr}"
    stdout
  end
end
