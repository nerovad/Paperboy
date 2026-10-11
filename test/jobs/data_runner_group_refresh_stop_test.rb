# frozen_string_literal: true

require 'test_helper'

class DataRunnerGroupRefreshStopTest < ActiveJob::TestCase
  test 'stops the running DSL and skips the rest when the run is cleared' do
    run = DataRunner::GroupRun.create!(run_id: SecureRandom.uuid, group_name: 'chart_of_accounts', total_count: 2)
    run.items.create!(dsl_name: 'Activities', dsl_slug: 'activities', position: 0)
    run.items.create!(dsl_name: 'Agencies', dsl_slug: 'agencies', position: 1)
    selectors = []
    started = Queue.new
    child_pid = nil
    child_status = nil
    success = Struct.new(:success?).new(true)
    runner = lambda do |selector:, on_start: nil, **|
      selectors << selector
      next success unless selector == 'activities'

      child_pid = Process.spawn('sleep', '30', pgroup: true)
      on_start&.call(child_pid)
      started << true
      child_status = wait_for_child(child_pid)
      success
    end
    stopper = Thread.new { run.destroy! if started.pop }

    DataRunner::GroupRefreshJob.stub(:download_concurrency, 1) do
      TaskRunner.stub(:run_selector!, runner) do
        DataRunner::DependentTruncate.stub(:perform, ->(*) { [] }) do
          DataRunner::GroupRefreshJob.perform_now(run.id)
        end
      end
    end

    assert_equal %w[activities], selectors
    assert_predicate child_status, :signaled?
    assert_nil DataRunner::GroupRun.find_by(id: run.id)
    assert_equal 0, DataRunner::GroupRunItem.where(group_run_id: run.id).count
    assert_includes TaskRunner.output!(run.run_id), '[STOP] Group refresh stopped. Progress was cleared.'
  ensure
    started << false if started
    stopper&.join(2)
    reap_refresh_child(child_pid)
    TaskRunner.output_path(run.run_id).delete if run&.run_id && TaskRunner.output_path(run.run_id).file?
  end

  private

  def wait_for_child(pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    loop do
      finished = Process.wait2(pid, Process::WNOHANG)
      return finished.last if finished
      raise 'refresh child was still running' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end

  def reap_refresh_child(pid)
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
