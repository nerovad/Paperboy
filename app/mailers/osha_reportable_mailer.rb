# frozen_string_literal: true

# Alerts the assigned safety officer when a reportable incident's 8-hour window
# for filing the OSHA 301 has run out and the report is still a draft. Sent once
# per report — see OshaReportableDeadlineJob.
class OshaReportableMailer < ApplicationMailer
  def filing_deadline_breached(osha_report_id)
    @report = OshaReport.find_by(id: osha_report_id)
    return if @report.nil?

    @due_at = @report.reportable_due_at
    @employee_name = @report.name

    recipients = (approver_email + safety_officer_emails).compact_blank.uniq
    if recipients.blank?
      # The breach is already stamped as notified, so a silent return here would
      # lose the alert entirely. Leave a trail.
      Rails.logger.warn("OshaReportableMailer: no recipients for overdue OSHA report #{osha_report_id}")
      return
    end

    mail(
      to: recipients,
      subject: "Overdue: OSHA 301 for #{@employee_name} was due #{@due_at&.strftime('%b %-d at %-l:%M %p')}"
    )
  end

  private

  def approver_email
    return [] if @report.approver_id.blank?

    [Employee.find_by(employee_id: @report.approver_id)&.email]
  end

  # Copies the safety officer group so a breach doesn't rest on one inbox. This
  # is the same group that gates the OSHA recordable/reportable fields on the
  # safety report form.
  def safety_officer_emails
    grp = Group.where('LOWER(Group_Name) = ?', 'hca_safety_officers').first
    return [] unless grp

    ids = EmployeeGroup.where(GroupID: grp.GroupID).pluck(:EmployeeID)
    Employee.where(id: ids).pluck(:email)
  rescue StandardError
    []
  end
end
