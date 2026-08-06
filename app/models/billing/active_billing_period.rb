# frozen_string_literal: true

module Billing
  class ActiveBillingPeriod < BillingBase
    self.table_name = 'GSABSS.dbo.Billing_Reporting_Period'
    self.primary_key = 'singleton_id'
    self.inheritance_column = nil

    alias_attribute :fiscal_year, :FYEAR
    alias_attribute :apmon, :APMON
    alias_attribute :start_date, :SDATE
    alias_attribute :end_date, :EDATE

    validates :singleton_id, inclusion: { in: [1] }
    validates :fiscal_year, :apmon, :start_date, :end_date, presence: true
    validate :ordered_dates

    def self.current
      find_by(singleton_id: 1)
    end

    def self.activate!(period)
      transaction do
        record = lock.find_or_initialize_by(singleton_id: 1)
        record.update!(
          fiscal_year: period.fetch('fyear'),
          apmon: period.fetch('apmon'),
          start_date: period.fetch('sdate').to_date,
          end_date: period.fetch('edate').to_date
        )
        record
      end
    end

    def display_text
      <<~TEXT.chomp
        Fiscal Year | APMON | Start Date | End Date
        #{fiscal_year} | #{apmon} | #{start_date.iso8601} | #{end_date.iso8601}
      TEXT
    end

    private

    def ordered_dates
      return if start_date.blank? || end_date.blank? || start_date <= end_date

      errors.add(:end_date, 'must be on or after start date')
    end
  end
end
