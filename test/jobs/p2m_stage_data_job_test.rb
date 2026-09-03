# frozen_string_literal: true

require 'test_helper'

class P2mStageDataJobTest < ActiveJob::TestCase
  test 'records successful staging completion' do
    run = DataRunner::GroupRun.create!(run_id: SecureRandom.uuid,
                                       group_name: P2m::StageData::GROUP_RUN_NAME, total_count: 1)
    arguments = nil
    staging = lambda do |**values|
      arguments = values
      { 'rows' => [] }
    end

    P2m::PrintAndInsertingDone.stub(:call, staging) do
      P2m::StageDataJob.perform_now(run.id, '2026-07-01', '2026-07-02')
    end

    assert_equal({ start_date: Date.new(2026, 7, 1), end_date: Date.new(2026, 7, 2) }, arguments)
    assert_equal 'succeeded', run.reload.status
    assert_equal 1, run.completed_count
  end
end
