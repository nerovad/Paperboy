# frozen_string_literal: true

module Billing
  class ReportGenerationJob < ApplicationJob
    queue_as :default

    def perform(operation:, start_date:, end_date:, recipients: [])
      report = MonthlyReport.new(
        operation: operation,
        start_date: start_date,
        end_date: end_date
      )
      raise ArgumentError, report.errors.full_messages.to_sentence unless report.valid?

      artifacts = ReportGenerator.new(report).call
      ReportWriter.new(artifacts).call
      email(artifacts, recipients) if operation == 'email'

      Rails.logger.info(
        "Billing #{operation} reports completed for #{start_date} through #{end_date}"
      )
    rescue StandardError => e
      Rails.logger.error(
        "Billing #{operation} reports failed for #{start_date} through #{end_date}: " \
        "#{e.class}: #{e.message}"
      )
      raise
    end

    private

    def email(artifacts, recipients)
      artifacts.each do |artifact|
        recipients.each do |recipient|
          BillingReportMailer.monthly_report(recipient, artifact).deliver_now
        end
      end
    end
  end
end
