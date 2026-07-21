# frozen_string_literal: true

# Hourly sweep for reportable OSHA 301s that blew their 8-hour filing window.
# Sends exactly one notice per report: the notified stamp is written before the
# mail is enqueued so a retry or an overlapping run can't send a second copy.
class OshaReportableDeadlineJob < ApplicationJob
  queue_as :default

  def perform
    OshaReport.reportable_breached.find_each do |report|
      next unless report.update(reportable_breach_notified_at: Time.current)

      OshaReportableMailer.filing_deadline_breached(report.id).deliver_later
    end
  end
end
