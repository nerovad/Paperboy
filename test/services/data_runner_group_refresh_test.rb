# frozen_string_literal: true

require 'test_helper'

class DataRunnerGroupRefreshTest < ActiveSupport::TestCase
  test 'rejects Print 2 Mail refresh entries without an OMS number' do
    entry = Data.define(:key, :slug).new(key: 'Oms', slug: 'oms')

    error = assert_raises(ArgumentError) do
      DataRunner::GroupRefresh.start!(group: P2m::DataRefresh::GROUP_RUN_NAME,
                                      entries: [entry], requested_by: 'employee@example.com')
    end

    assert_match 'require an OMS number', error.message
  end

  test 'restart fails the interrupted run and queues a replacement' do
    interrupted = DataRunner::GroupRun.create!(run_id: SecureRandom.uuid, group_name: 'sample',
                                               status: 'running', total_count: 1)
    item = interrupted.items.create!(dsl_name: 'Sample', dsl_slug: 'sample', position: 0,
                                     status: 'running', started_at: 1.minute.ago)
    entry = Struct.new(:key, :slug).new('Sample', 'sample')
    enqueued_run_id = nil

    DataRunner::GroupRefreshJob.stub(:perform_later, ->(run_id) { enqueued_run_id = run_id }) do
      replacement = DataRunner::GroupRefresh.restart!(
        group: 'sample', entries: [entry], requested_by: 'employee@example.com'
      )

      assert_equal 'failed', interrupted.reload.status
      assert_equal 1, interrupted.completed_count
      assert_equal 1, interrupted.failed_count
      assert_equal 'failed', item.reload.status
      assert_equal 'Interrupted refresh was restarted', item.error_message
      assert_equal 'queued', replacement.status
      assert_equal replacement.id, enqueued_run_id
    end
  end

  test 'raises queue unavailable when Redis refuses the enqueue' do
    entry = Struct.new(:key, :slug).new('Sample', 'sample')
    error = StandardError.new('enqueue failed')
    error.define_singleton_method(:cause) { Errno::ECONNREFUSED.new }

    DataRunner::GroupRefreshJob.stub(:perform_later, ->(_) { raise error }) do
      assert_raises(DataRunner::GroupRefresh::QueueUnavailable) do
        DataRunner::GroupRefresh.start!(
          group: 'sample', entries: [entry], requested_by: 'employee@example.com'
        )
      end
    end
  end
end
