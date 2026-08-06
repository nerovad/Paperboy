# frozen_string_literal: true

module Billing
  class EmailSubject < BillingBase
    self.table_name = 'GSABSS.dbo.Billing_Email_Subjects'
    self.primary_key = 'billing_type'

    validates :billing_type, :subject_format, presence: true

    # rubocop:disable Style/FormatStringToken
    def self.default_format(billing_type)
      "%{fiscal_year}.%{apmon} - #{billing_type}"
    end
    # rubocop:enable Style/FormatStringToken

    def render(active_period)
      format(
        subject_format,
        fiscal_year: active_period.fiscal_year,
        apmon: active_period.apmon,
        type: billing_type
      )
    rescue KeyError, ArgumentError
      subject_format
    end
  end
end
