# frozen_string_literal: true

class BillingReportMailer < ApplicationMailer
  def billing_report(recipients, message)
    message.attachments.each do |report_file|
      attachments[report_file.filename] = report_file.path.binread
    end
    @body = message.body
    mail(to: recipients, subject: message.subject)
  end
end
