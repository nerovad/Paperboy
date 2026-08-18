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
    assert_includes TaskRunner.output!(run.run_id), 'Processed agencies'
  ensure
    TaskRunner.output_path(run.run_id).delete if run&.run_id && TaskRunner.output_path(run.run_id).file?
  end
end
