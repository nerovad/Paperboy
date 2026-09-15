# frozen_string_literal: true

# Runs one ScheduledRecordExport: rebuilds its saved grid view against live
# rows and emails the owner the CSV.
#
# Access is checked here, at send time, from the owner's employee id (see
# EmployeePermissions) — a schedule is a standing copy of a table, so losing
# the grant has to stop the emails, not just hide the grid. A schedule whose
# owner can no longer open its table, or whose table is gone, is paused and
# the owner told why; it is not deleted, so an admin who restores the grant
# only needs the owner to press Resume.
class RecordExportJob < ApplicationJob
  queue_as :default

  def perform(schedule_id)
    schedule = ScheduledRecordExport.find_by(id: schedule_id)
    return unless schedule&.enabled?

    employee = Submitter.resolve(schedule.employee_id)
    return schedule.update!(enabled: false) if employee&.email.blank?

    table = schedule.table
    unless table && EmployeePermissions.new(schedule.employee_id).can_access_record_table?(table)
      schedule.update!(enabled: false)
      ReportMailer.record_export_paused(employee, schedule).deliver_now
      return
    end

    view = schedule.build_view
    ReportMailer.record_export_ready(employee, schedule, RecordsCsv.generate(view), view.rows.size).deliver_now
  rescue StandardError => e
    Rails.logger.error "Scheduled record export ##{schedule_id} failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    ReportMailer.record_export_failed(employee, schedule, e.message).deliver_now if employee && schedule
  end
end
