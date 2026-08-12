# frozen_string_literal: true

module Billing
  class ReportGenerationJob < ApplicationJob
    queue_as :default

    def perform(operation:, start_date:, end_date:, version:)
      report = MonthlyReport.new(
        operation: operation,
        start_date: start_date,
        end_date: end_date,
        version: version
      )
      raise ArgumentError, report.errors.full_messages.to_sentence unless report.valid?

      artifacts = ReportGenerator.new(report).call
      active_types = BillingType.where(ACTIVE: true).pluck(:TYPE)
      ReportWriter.new(artifacts, replace_types: active_types).call
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
  end
end
