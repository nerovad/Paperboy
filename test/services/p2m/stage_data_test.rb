# frozen_string_literal: true

require 'test_helper'

module P2m
  class StageDataTest < ActiveSupport::TestCase
    test 'creates one queued Sidekiq job' do
      enqueued = nil

      StageDataJob.stub(:perform_later, ->(*arguments) { enqueued = arguments }) do
        run = StageData.enqueue!(
          start_date: Date.new(2026, 7, 1),
          end_date: Date.new(2026, 7, 2),
          requested_by: 'employee@example.com'
        )

        assert_equal 'queued', run.status
        assert_equal [run.id, '2026-07-01', '2026-07-02'], enqueued
      end
    end

    test 'rejects a second active staging job' do
      DataRunner::GroupRun.create!(run_id: SecureRandom.uuid, group_name: StageData::GROUP_RUN_NAME)

      assert_raises(StageData::ActiveRun) do
        StageData.enqueue!(
          start_date: Date.new(2026, 7, 1),
          end_date: Date.new(2026, 7, 2),
          requested_by: 'employee@example.com'
        )
      end
    end
  end
end
