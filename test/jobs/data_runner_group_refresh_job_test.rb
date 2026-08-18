# frozen_string_literal: true

require 'test_helper'

class DataRunnerGroupRefreshJobTest < ActiveJob::TestCase
  test 'records each DSL result and continues after failure' do
    run = DataRunner::GroupRun.create!(run_id: SecureRandom.uuid, group_name: 'chart_of_accounts', total_count: 2)
    run.items.create!(dsl_name: 'Activities', dsl_slug: 'activities', position: 0)
    run.items.create!(dsl_name: 'Agencies', dsl_slug: 'agencies', position: 1)
    success = Struct.new(:success?).new(true)
    failure = Struct.new(:success?).new(false)
    runner = lambda do |selector:, output:, **|
      output.puts "Processed #{selector}"
      selector == 'activities' ? success : failure
    end

    TaskRunner.stub(:run_selector!, runner) do
      DataRunner::GroupRefreshJob.perform_now(run.id)
    end

    run.reload
    assert_equal 'failed', run.status
    assert_equal 2, run.completed_count
    assert_equal 1, run.failed_count
    assert_equal %w[succeeded failed], run.items.order(:position).pluck(:status)
    assert(run.items.all? { |item| item.duration_ms.is_a?(Integer) })
    assert_includes TaskRunner.output!(run.run_id), 'Processed agencies'
  ensure
    TaskRunner.output_path(run.run_id).delete if run&.run_id && TaskRunner.output_path(run.run_id).file?
  end

  test 'refreshes at most four DSLs in parallel' do
    run = DataRunner::GroupRun.create!(run_id: SecureRandom.uuid, group_name: 'parallel', total_count: 6)
    6.times { |position| run.items.create!(dsl_name: "DSL #{position}", dsl_slug: "dsl_#{position}", position: position) }
    success = Struct.new(:success?).new(true)
    lock = Mutex.new
    active = 0
    maximum_active = 0
    runner = lambda do |**|
      lock.synchronize do
        active += 1
        maximum_active = [maximum_active, active].max
      end
      sleep 0.02
      success
    ensure
      lock.synchronize { active -= 1 }
    end

    TaskRunner.stub(:run_selector!, runner) do
      DataRunner::GroupRefreshJob.perform_now(run.id)
    end

    assert_equal 4, maximum_active
    assert_equal 6, run.reload.completed_count
  ensure
    TaskRunner.output_path(run.run_id).delete if run&.run_id && TaskRunner.output_path(run.run_id).file?
  end
end
