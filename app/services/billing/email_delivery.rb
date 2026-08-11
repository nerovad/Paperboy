# frozen_string_literal: true

module Billing
  class EmailDelivery
    Message = Data.define(:report_name, :subject, :body, :attachments)

    def initialize(reports:, active_period:)
      @reports = reports
      @active_period = active_period
    end

    def messages
      subjects = EmailSubject.where(billing_type: reports.map(&:billing_type)).index_by(&:billing_type)
      reports.map do |report|
        subject = subjects[report.billing_type]&.render(active_period) || fallback_subject(report)
        Message.new(
          report_name: report.name,
          subject: subject,
          body: subject,
          attachments: report.files
        )
      end
    end

    def deliver(recipients)
      messages.each do |message|
        BillingReportMailer.billing_report(recipients, message).deliver_now
      end
      active_period.increment_version!
    end

    private

    attr_reader :reports, :active_period

    def fallback_subject(report)
      "#{active_period.fiscal_year}.#{active_period.apmon} - #{report.billing_type} - #{report.name}"
    end
  end
end
