# frozen_string_literal: true

# app/jobs/scheduled_reports_runner_job.rb
#
# Polled every minute by sidekiq-cron. Executes every due schedule: form
# reports (ScheduledReport) and Records grid exports (ScheduledRecordExport).
class ScheduledReportsRunnerJob < ApplicationJob
  queue_as :default

  SCHEDULES = [ScheduledReport, ScheduledRecordExport].freeze

  def perform
    Rails.logger.info 'Checking for scheduled reports due to run...'

    SCHEDULES.each { |schedule_class| run_due(schedule_class) }
  end

  private

  def run_due(schedule_class)
    # Find all schedules that are due
    due_schedules = schedule_class.due

    Rails.logger.info "Found #{due_schedules.count} #{schedule_class.model_name.human.pluralize.downcase} due to run"

    due_schedules.each do |schedule|
      Rails.logger.info "Executing #{schedule_class.name} ##{schedule.id} for employee #{schedule.employee_id}"
      schedule.execute!
    rescue StandardError => e
      Rails.logger.error "Failed to execute #{schedule_class.name} ##{schedule.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      # Continue with other schedules
    end
  end
end
