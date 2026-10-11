# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'shellwords'
require 'tmpdir'

# rubocop:disable-next Metrics/ClassLength
class StopserversTest < Minitest::Test
  SCRIPT = Pathname.new(__dir__).join('../..', 'bin/stopservers').realpath

  def test_stops_only_the_recorded_stack_for_the_requested_port
    Dir.mktmpdir('paperboy-stopservers') do |root|
      root = Pathname.new(root)
      bin = root.join('bin')
      pid_dir = root.join('tmp/pids')
      bin.mkpath
      pid_dir.mkpath
      FileUtils.cp(SCRIPT, bin.join('stopservers'))
      FileUtils.chmod(0o755, bin.join('stopservers'))

      stopped_stack = start_stack(root, 3001, pid_dir)
      other_stack = start_stack(root, 3002, pid_dir, components: [:server])

      stdout, stderr, status = Open3.capture3(bin.join('stopservers').to_s, '3001', chdir: root.to_s)

      assert status.success?, "stopservers failed: #{stdout}\n#{stderr}"
      stopped_stack.each { |pid| assert_process_stopped(pid) }
      other_stack.each { |pid| assert_process_alive(pid) }
    ensure
      (stopped_stack || []).concat(other_stack || []).each { |pid| stop_process(pid) }
    end
  end

  def test_defaults_to_port_3001_from_another_working_directory
    Dir.mktmpdir('paperboy-stopservers-default') do |root|
      root = Pathname.new(root)
      bin = root.join('bin')
      pid_dir = root.join('tmp/pids')
      bin.mkpath
      pid_dir.mkpath
      FileUtils.cp(SCRIPT, bin.join('stopservers'))
      FileUtils.chmod(0o755, bin.join('stopservers'))

      stopped_stack = start_stack(root, 3001, pid_dir, components: [:server])
      other_stack = start_stack(root, 3002, pid_dir, components: [:server])

      stdout, stderr, status = Open3.capture3(bin.join('stopservers').to_s, chdir: Dir.tmpdir)

      assert status.success?, "stopservers failed: #{stdout}\n#{stderr}"
      stopped_stack.each { |pid| assert_process_stopped(pid) }
      other_stack.each { |pid| assert_process_alive(pid) }
    ensure
      (stopped_stack || []).concat(other_stack || []).each { |pid| stop_process(pid) }
    end
  end

  def test_stops_a_legacy_server_without_a_pid_manifest
    Dir.mktmpdir('paperboy-stopservers-legacy') do |root|
      root = Pathname.new(root)
      bin = root.join('bin')
      pid_dir = root.join('tmp/pids')
      bin.mkpath
      pid_dir.mkpath
      FileUtils.cp(SCRIPT, bin.join('stopservers'))
      FileUtils.chmod(0o755, bin.join('stopservers'))

      stopped_stack = start_stack(root, 3002, pid_dir, components: [:server])
      pid_dir.join('paperboy-dev-3002.pids').delete

      stdout, stderr, status = Open3.capture3(bin.join('stopservers').to_s, '3002', chdir: root.to_s)

      assert status.success?, "stopservers failed: #{stdout}\n#{stderr}"
      stopped_stack.each { |pid| assert_process_stopped(pid) }
    ensure
      (stopped_stack || []).each { |pid| stop_process(pid) }
    end
  end

  def test_succeeds_when_no_server_is_running
    Dir.mktmpdir('paperboy-stopservers-empty') do |root|
      root = Pathname.new(root)
      bin = root.join('bin')
      bin.mkpath
      FileUtils.cp(SCRIPT, bin.join('stopservers'))
      FileUtils.chmod(0o755, bin.join('stopservers'))

      stdout, stderr, status = Open3.capture3(bin.join('stopservers').to_s, '3002', chdir: root.to_s)

      assert status.success?, "stopservers failed: #{stdout}\n#{stderr}"
    end
  end

  def test_stops_a_datarunner_process_group_after_the_server_is_gone
    other_root = Dir.mktmpdir('paperboy-stopservers-other-checkout')
    Dir.mktmpdir('paperboy-stopservers-datarunner') do |root|
      root = Pathname.new(root)
      bin = root.join('bin')
      bin.mkpath
      FileUtils.cp(SCRIPT, bin.join('stopservers'))
      FileUtils.chmod(0o755, bin.join('stopservers'))

      refresh = spawn_named(root, 'ruby bin/rake DataRunner:refresh Sample', 'sleep 30 & wait')
      child_pid = child_of(refresh)
      assert child_pid.positive?, 'the refresh did not start a child'
      bystander = Process.spawn('sleep', '30', chdir: root.to_s, pgroup: true)
      other_refresh = spawn_named(other_root, 'ruby bin/rake DataRunner:refresh Other', 'sleep 30')

      stdout, stderr, status = Open3.capture3(bin.join('stopservers').to_s, '3105', chdir: root.to_s)

      assert status.success?, "stopservers failed: #{stdout}\n#{stderr}"
      assert_process_stopped(refresh)
      refute child_pid.positive? && process_alive?(child_pid), 'the inject child is still running'
      assert_process_alive(bystander)
      assert_process_alive(other_refresh)
    ensure
      [refresh, bystander, other_refresh].compact.each { |pid| stop_process(pid) }
    end
  ensure
    FileUtils.remove_entry(other_root) if other_root
  end

  def test_kills_a_datarunner_group_forked_while_the_server_exits
    Dir.mktmpdir('paperboy-stopservers-race') do |root|
      root = Pathname.new(root)
      bin = root.join('bin')
      pid_dir = root.join('tmp/pids')
      bin.mkpath
      pid_dir.mkpath
      FileUtils.cp(SCRIPT, bin.join('stopservers'))
      FileUtils.chmod(0o755, bin.join('stopservers'))

      jobs = spawn_named(root, 'bundle exec bin/jobs', <<~RUBY)
        ruby -e '
          trap("TERM") do
            Process.fork do
              Process.setpgid(0, 0)
              File.write("refresh.pid", Process.pid)
              exec(["sleep", "ruby bin/rake DataRunner:refresh Sample"], "30")
            end
          end
          sleep 30
        '
      RUBY
      pid_dir.join('paperboy-dev-3105.pids').write("#{jobs}\n")
      bystander = Process.spawn('sleep', '30', chdir: root.to_s, pgroup: true)

      stdout, stderr, status = Open3.capture3(bin.join('stopservers').to_s, '3105', chdir: root.to_s)

      assert status.success?, "stopservers failed: #{stdout}\n#{stderr}"
      assert_match(/sending KILL/, stderr)
      assert_process_stopped(jobs)
      refresh_pid = root.join('refresh.pid').read.to_i
      refute process_alive?(refresh_pid), 'the refresh forked during shutdown is still running'
      assert_process_alive(bystander)
    ensure
      stop_process(jobs) if jobs
      stop_process(bystander) if bystander
      refresh_pid = root.join('refresh.pid').read.to_i if root.join('refresh.pid').file?
      stop_process(refresh_pid) if refresh_pid
    end
  end

  def test_kills_a_datarunner_group_forked_as_the_server_exits
    Dir.mktmpdir('paperboy-stopservers-exit-race') do |root|
      root = Pathname.new(root)
      bin = root.join('bin')
      pid_dir = root.join('tmp/pids')
      bin.mkpath
      pid_dir.mkpath
      FileUtils.cp(SCRIPT, bin.join('stopservers'))
      FileUtils.chmod(0o755, bin.join('stopservers'))

      jobs = spawn_named(root, 'bundle exec bin/jobs', <<~RUBY)
        ruby -e '
          trap("TERM") do
            pid = Process.fork do
              Process.setpgid(0, 0)
              File.write("refresh.pid", Process.pid)
              exec(["sleep", "ruby bin/rake DataRunner:refresh Sample"], "30")
            end
            Process.detach(pid)
            exit
          end
          sleep 30
        '
      RUBY
      pid_dir.join('paperboy-dev-3105.pids').write("#{jobs}\n")
      sleep 0.2

      stdout, stderr, status = Open3.capture3(bin.join('stopservers').to_s, '3105', chdir: root.to_s)

      assert status.success?, "stopservers failed: #{stdout}\n#{stderr}"
      assert_process_stopped(jobs)
      refresh_pid = root.join('refresh.pid').read.to_i
      refute process_alive?(refresh_pid), 'the refresh forked as the server exited is still running'
    ensure
      stop_process(jobs) if jobs
      refresh_pid = root.join('refresh.pid').read.to_i if root.join('refresh.pid').file?
      stop_process(refresh_pid) if refresh_pid
    end
  end

  def test_kills_a_stubborn_process_group_and_its_child
    Dir.mktmpdir('paperboy-stopservers-stubborn') do |root|
      root = Pathname.new(root)
      bin = root.join('bin')
      pid_dir = root.join('tmp/pids')
      bin.mkpath
      pid_dir.mkpath
      FileUtils.cp(SCRIPT, bin.join('stopservers'))
      FileUtils.chmod(0o755, bin.join('stopservers'))

      pid = Process.spawn('bash', '-c', <<~BASH, chdir: root.to_s, pgroup: true)
        exec -a 'bundle exec bin/jobs' bash -c 'trap "" TERM; sleep 30 & wait'
      BASH
      child_pid = nil
      10.times do
        child_pid = `pgrep -P #{pid}`.to_i
        break if child_pid.positive?

        sleep 0.1
      end
      pid_dir.join('paperboy-dev-3002.pids').write("#{pid}\n")

      stdout, stderr, status = Open3.capture3(bin.join('stopservers').to_s, '3002', chdir: root.to_s)

      assert status.success?, "stopservers failed: #{stdout}\n#{stderr}"
      assert_process_stopped(pid)
      refute child_pid.positive? && process_alive?(child_pid), 'the child is still running'
    ensure
      stop_process(pid) if pid
    end
  end

  private

  def spawn_named(root, name, script)
    Process.spawn('bash', '-c',
                  "exec -a #{Shellwords.escape(name)} bash -c #{Shellwords.escape(script)}",
                  chdir: root.to_s, pgroup: true)
  end

  def child_of(pid)
    child_pid = 0
    10.times do
      child_pid = `pgrep -P #{pid}`.to_i
      break if child_pid.positive?

      sleep 0.1
    end
    child_pid
  end

  def start_stack(root, port, pid_dir, components: %i[server jobs sass])
    pids = components.map do |component|
      command = case component
                when :server then "bundle exec rails server -p #{port} -b 127.0.0.1"
                when :jobs then 'bundle exec bin/jobs'
                when :sass then 'bundle exec rails dartsass:watch'
                end
      Process.spawn('bash', '-c', "exec -a #{Shellwords.escape(command)} sleep 30",
                    chdir: root.to_s, pgroup: true)
    end
    pid_dir.join("paperboy-dev-#{port}.pids").write("#{pids.join("\n")}\n")
    pids
  end

  def assert_process_stopped(pid)
    Process.wait(pid)
  rescue Errno::ECHILD
    refute process_alive?(pid), "process #{pid} is still running"
  end

  def assert_process_alive(pid)
    assert process_alive?(pid), "process #{pid} was stopped"
  end

  def process_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end

  def stop_process(pid)
    Process.kill('TERM', -Process.getpgid(pid)) if process_alive?(pid)
  rescue Errno::ESRCH
    nil
  ensure
    begin
      Process.wait(pid)
    rescue Errno::ECHILD, Errno::ESRCH
      nil
    end
  end
end
