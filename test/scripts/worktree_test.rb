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
