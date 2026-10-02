# frozen_string_literal: true

require 'fileutils'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'shellwords'
require 'tmpdir'

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

  private

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
