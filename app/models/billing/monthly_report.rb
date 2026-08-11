# frozen_string_literal: true

module Billing
  class MonthlyReport
    include ActiveModel::Model

    OPERATIONS = {
      'run' => {
        title: 'Run Billing', button: 'Run Billing',
        procedures: ['GSABSS.dbo.MonthlyBilling']
      },
      'print' => {
        title: 'Print Billing Reports', button: 'Print Billing Reports',
        procedures: %w[GSABSS.dbo.Export_TC60_Billing_Report_Names
                       GSABSS.dbo.Export_TC60_To_Billing_File]
      }
    }.freeze

    attr_accessor :operation, :start_date, :end_date, :version

    validates :operation, inclusion: { in: OPERATIONS.keys }
    validates :start_date, :end_date, presence: true
    validate :start_date_precedes_end_date

    def configuration
      OPERATIONS.fetch(operation)
    end

    def title
      configuration.fetch(:title)
    end

    def button_label
      configuration.fetch(:button)
    end

    def procedure_names
      configuration.fetch(:procedures)
    end

    def procedure_text
      procedure_names.join("\n")
    end

    def start_on
      Date.iso8601(start_date)
    end

    def end_on
      Date.iso8601(end_date)
    end

    private

    def start_date_precedes_end_date
      return if start_date.blank? || end_date.blank?
      return if start_on <= end_on

      errors.add(:end_date, 'must be on or after start date')
    rescue Date::Error
      errors.add(:base, 'Start date and end date must be valid dates')
    end
  end
end
