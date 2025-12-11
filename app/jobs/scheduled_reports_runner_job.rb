# app/jobs/scheduled_reports_runner_job.rb
class ScheduledReportsRunnerJob < ApplicationJob
  queue_as :default
  
  def perform
    Rails.logger.info "Checking for scheduled reports due to run..."
    
    # Find all scheduled reports that are due
    due_reports = ScheduledReport.due
    
    Rails.logger.info "Found #{due_reports.count} scheduled reports due to run"
    
    due_reports.each do |report|
      begin
        Rails.logger.info "Executing scheduled report ##{report.id} for employee #{report.employee_id}"
        report.execute!
      rescue StandardError => e
        Rails.logger.error "Failed to execute scheduled report ##{report.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        # Continue with other reports
      end
    end
  end
end
