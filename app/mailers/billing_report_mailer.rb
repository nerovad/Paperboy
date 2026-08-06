# frozen_string_literal: true

class BillingReportMailer < ApplicationMailer
  def monthly_report(recipient, artifact)
    attachments[File.basename(artifact.pdf_name)] = artifact.pdf_data
    attachments[File.basename(artifact.xlsx_name)] = artifact.xlsx_data
    mail(to: recipient, subject: artifact.name)
  end
end
