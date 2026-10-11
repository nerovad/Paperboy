# frozen_string_literal: true

require 'test_helper'

class DataRunnerRefreshStopTest < ActiveSupport::TestCase
  test 'stop terminates a tracked process group' do
    pid = Process.spawn('sleep', '30', pgroup: true)
    stop = DataRunner::RefreshStop.new
    stop.track(pid)
    stop.stop!

    _stopped_pid, status = Process.wait2(pid)
    assert_predicate status, :signaled?
    assert_equal Signal.list.fetch('TERM'), status.termsig
    pid = nil
  ensure
    reap_process_group(pid)
  end

  test 'track kills a process that starts after the refresh has stopped' do
    stop = DataRunner::RefreshStop.new
    stop.stop!
    pid = Process.spawn('sleep', '30', pgroup: true)
    stop.track(pid)

    _stopped_pid, status = Process.wait2(pid)
    assert_predicate status, :signaled?
    pid = nil
  ensure
    reap_process_group(pid)
  end

  private

  def reap_process_group(pid)
    return unless pid

    begin
      Process.kill('TERM', -pid)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end
    Process.wait2(pid)
  rescue Errno::ECHILD
    nil
  end
end
