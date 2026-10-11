# frozen_string_literal: true

require 'test_helper'

class DataRunnerGroupRunItemTest < ActiveSupport::TestCase
  test 'records the step only while the item is running' do
    run = DataRunner::GroupRun.create!(run_id: SecureRandom.uuid, group_name: 'calsaws', total_count: 1)
    item = run.items.create!(dsl_name: 'Calsaws_exportimage', dsl_slug: 'calsaws-exportimage', position: 0,
                             status: 'running', started_at: Time.current)

    DataRunner::GroupRunItem.record_step(item.id, :download)

    assert_equal 'download', item.reload.current_step

    item.update!(status: 'succeeded', completed_at: Time.current)
    DataRunner::GroupRunItem.record_step(item.id, :inject)

    assert_equal 'download', item.reload.current_step
  end
end
