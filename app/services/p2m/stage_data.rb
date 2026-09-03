# frozen_string_literal: true

module P2m
  class StageData
    GROUP_RUN_NAME = 'p2m_stage_data'

    class ActiveRun < StandardError; end

    def self.enqueue!(start_date:, end_date:, requested_by:)
      run = nil
      DataRunner::GroupRun.transaction do
        raise ActiveRun if active_run

        run = DataRunner::GroupRun.create!(
          run_id: SecureRandom.uuid,
          group_name: GROUP_RUN_NAME,
          total_count: 1,
          requested_by: requested_by
        )
      end
      StageDataJob.perform_later(run.id, start_date.iso8601, end_date.iso8601)
      run
    rescue StandardError
      run&.update(status: 'failed', completed_at: Time.current) if run&.persisted?
      raise
    end

    def self.active_run
      DataRunner::GroupRun.active.find_by(group_name: GROUP_RUN_NAME)
    end
  end
end
