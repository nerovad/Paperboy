# frozen_string_literal: true

module P2m
  class StageDataJob < ApplicationJob
    queue_as :default

    def perform(group_run_id, start_date, end_date)
      run = DataRunner::GroupRun.find(group_run_id)
      return unless run.status == 'queued'

      run.update!(status: 'running', started_at: Time.current)
      PrintAndInsertingDone.call(start_date: Date.iso8601(start_date), end_date: Date.iso8601(end_date))
      run.update!(status: 'succeeded', completed_count: 1, completed_at: Time.current)
    rescue StandardError
      run&.update(status: 'failed', failed_count: 1, completed_at: Time.current)
      raise
    end
  end
end
