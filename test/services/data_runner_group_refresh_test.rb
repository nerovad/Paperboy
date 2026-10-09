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

  test 'restart clears the interrupted run and queues a replacement from the start' do
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

      assert_nil DataRunner::GroupRun.find_by(id: interrupted.id)
      assert_nil DataRunner::GroupRunItem.find_by(id: item.id)
      assert_equal 'queued', replacement.status
      assert_equal 0, replacement.completed_count
      assert_equal 0, replacement.failed_count
      assert_equal ['pending'], replacement.items.pluck(:status)
      assert_equal replacement.id, enqueued_run_id
    end
  end

  test 'raises queue unavailable when the job queue refuses the enqueue' do
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
