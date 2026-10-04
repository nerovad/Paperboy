# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'tmpdir'

# bin/env-pull replaces .env with LockBox's copy on every deploy, so what it
# must never do is lose a variable quietly or touch .env.local.
class EnvPullTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir('env-pull')
    @app = File.join(@root, 'Paperboy')
    @lockbox = File.join(@root, 'LockBox')
    FileUtils.mkdir_p([File.join(@app, 'bin'), @lockbox])
    FileUtils.cp(Rails.root.join('bin/env-pull'), File.join(@app, 'bin/env-pull'))
    system('git', 'init', '-q', @lockbox, exception: true)
    lockbox("SHARED=one\nSECRET=hunter2\n")
  end

  teardown { FileUtils.remove_entry(@root) }

  test 'creates .env from LockBox when there is none' do
    output, status = env_pull

    assert status.success?, output
    assert_equal "SHARED=one\nSECRET=hunter2\n", app_file('.env')
    assert_equal 0o600, File.stat(File.join(@app, '.env')).mode & 0o777
  end

  test 'replaces .env, keeps the old copy and names what changed without values' do
    write('.env', "SHARED=old\nSECRET=hunter2\n")
    lockbox("SHARED=one\nSECRET=hunter2\nADDED=new-value\n")

    output, status = env_pull

    assert status.success?, output
    assert_equal "SHARED=one\nSECRET=hunter2\nADDED=new-value\n", app_file('.env')
    assert_equal "SHARED=old\nSECRET=hunter2\n", app_file('.env.previous')
    assert_match(/added:\s+ADDED/, output)
    assert_match(/changed:\s+SHARED/, output)
    assert_no_match(/hunter2|new-value|old/, output)
  end

  test 'refuses to lose a variable that is in neither LockBox nor .env.local' do
    write('.env', "SHARED=one\nSECRET=hunter2\nMINE=here\n")

    output, status = env_pull

    assert_not status.success?
    assert_match(/would lose them:\s+MINE/, output)
    assert_equal "SHARED=one\nSECRET=hunter2\nMINE=here\n", app_file('.env')
  end

  test 'a variable moved to .env.local no longer blocks, and .env.local is untouched' do
    write('.env', "SHARED=one\nSECRET=hunter2\nMINE=here\n")
    write('.env.local', "MINE=here\nSHARED=local\n")

    output, status = env_pull

    assert status.success?, output
    assert_equal "SHARED=one\nSECRET=hunter2\n", app_file('.env')
    assert_equal "MINE=here\nSHARED=local\n", app_file('.env.local')
    assert_match(/still overridden by \.env\.local:\s+SHARED/, output)
  end

  test '--prune drops variables LockBox does not have' do
    write('.env', "SHARED=one\nSECRET=hunter2\nMINE=here\n")

    output, status = env_pull('--prune')

    assert status.success?, output
    assert_equal "SHARED=one\nSECRET=hunter2\n", app_file('.env')
  end

  test '--check reports and writes nothing' do
    write('.env', "SHARED=old\nSECRET=hunter2\n")

    output, status = env_pull('--check')

    assert status.success?, output
    assert_match(/changed:\s+SHARED/, output)
    assert_equal "SHARED=old\nSECRET=hunter2\n", app_file('.env')
    assert_not File.exist?(File.join(@app, '.env.previous'))
  end

  test 'does nothing when .env already matches' do
    write('.env', "SHARED=one\nSECRET=hunter2\n")

    output, status = env_pull

    assert status.success?, output
    assert_match(/already matches LockBox/, output)
    assert_not File.exist?(File.join(@app, '.env.previous'))
  end

  test 'stops when there is no LockBox checkout' do
    FileUtils.remove_entry(@lockbox)

    output, status = env_pull

    assert_not status.success?
    assert_match(/no LockBox checkout/, output)
  end

  private

  def env_pull(*args)
    Open3.capture2e({ 'LOCKBOX_DIR' => nil }, File.join(@app, 'bin/env-pull'), *args)
  end

  def lockbox(contents)
    File.write(File.join(@lockbox, 'Paperboy.env'), contents)
  end

  def write(name, contents)
    File.write(File.join(@app, name), contents)
  end

  def app_file(name)
    File.read(File.join(@app, name))
  end
end
