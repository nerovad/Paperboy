# frozen_string_literal: true

module Development
  class QueueController < BaseController
    def show
      @processes = SolidQueue::Process.order(last_heartbeat_at: :desc)
      @queued_jobs = SolidQueue::ReadyExecution.includes(:job).order(created_at: :desc).limit(25)
      @running_jobs = SolidQueue::ClaimedExecution.includes(:job).order(created_at: :desc).limit(25)
      @failed_jobs = SolidQueue::FailedExecution.includes(:job).order(id: :desc).limit(10)
    end
  end
end
