# frozen_string_literal: true

require 'test_helper'
require 'timeout'

class DataRunnerGroupRefreshTimerTest < ActiveJob::TestCase
  test 'starts a DSL timer when that DSL starts processing' do
    run = DataRunner::GroupRun.create!(run_id: SecureRandom.uuid, group_name: 'chart_of_accounts', total_count: 2)
    run.items.create!(dsl_name: 'Activities', dsl_slug: 'activities', position: 0)
    run.items.create!(dsl_name: 'Agencies', dsl_slug: 'agencies', position: 1)
    started = Queue.new
    release = Queue.new
    success = Struct.new(:success?).new(true)
    runner = lambda do |selector:, **|
      if selector == 'activities'
        started << true
        release.pop
      end
      success
    end
    worker = Thread.new do
      DataRunner::GroupRefreshJob.stub(:download_concurrency, 1) do
        TaskRunner.stub(:run_selector!, runner) do
          DataRunner::DependentTruncate.stub(:perform, ->(*) { [] }) do
            DataRunner::GroupRefreshJob.perform_now(run.id)
          end
        end
      end
    end

    Timeout.timeout(5) { started.pop }
    items = run.items.order(:position).map(&:reload)
    assert_equal 'running', items.first.status
    assert items.first.started_at
    assert_equal 'pending', items.second.status
    assert_nil items.second.started_at
    release << true
    worker.value

    finished = run.items.order(:position).map(&:reload)
    assert_operator finished.second.started_at, :>=, finished.first.completed_at
  ensure
    release << true if release && worker&.alive?
    worker&.join(2)
    TaskRunner.output_path(run.run_id).delete if run&.run_id && TaskRunner.output_path(run.run_id).file?
  end
end
