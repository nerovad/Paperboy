# frozen_string_literal: true

require 'test_helper'

class DataRunnerLogTest < ActiveSupport::TestCase
  setup do
    ActiveRecord::Base.connection.create_table(:datarunner_log, force: true) do |table|
      table.string :run_id
      table.string :command
      table.string :script
      table.text :arguments
      table.string :selector
      table.string :status
      table.integer :exit_status
      table.datetime :started_at
      table.datetime :completed_at
      table.integer :duration_ms
    end
  end

  test 'search filters logs by command dsl status date and duration' do
    matching = create_log(command: 'refresh', selector: 'chart_of_accounts', status: 'succeeded',
                          started_at: Time.zone.local(2026, 6, 22, 10), duration_ms: 5_000)
    create_log(command: 'oneshot', selector: 'employees', status: 'failed',
               started_at: Time.zone.local(2026, 6, 21, 10), duration_ms: 70_000)

    result = DataRunner::Log.search(
      date: '2026-06-22', command: 'refresh', dsl: 'chart_of_accounts',
      status: 'succeeded', duration: '1s_to_10s'
    )

    assert_equal [matching], result.to_a
  end

  private

  def create_log(attributes)
    now = attributes.fetch(:started_at)
    DataRunner::Log.create!(
      {
        run_id: SecureRandom.uuid,
        command: 'refresh',
        script: 'download.rb',
        selector: 'employees',
        status: 'succeeded',
        started_at: now,
        completed_at: now,
        duration_ms: 0
      }.merge(attributes)
    )
  end
end
