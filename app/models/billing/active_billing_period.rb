# frozen_string_literal: true

module Billing
  class ActiveBillingPeriod < BillingBase
    self.table_name = 'GSABSS.dbo.Billing_Reporting_Period'
    self.primary_key = 'billing_reporting_period_id'
    self.inheritance_column = nil

    alias_attribute :fiscal_year, :FYEAR
    alias_attribute :apmon, :APMON
    alias_attribute :start_date, :SDATE
    alias_attribute :end_date, :EDATE
    alias_attribute :version, :VERSION
    alias_attribute :active, :ACTIVE

    validates :fiscal_year, :apmon, :start_date, :end_date, presence: true
    validates :version, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :apmon, uniqueness: { scope: :fiscal_year }
    validate :ordered_dates

    def self.current
      find_by(active: true)
    end

    def self.activate!(period)
      transaction do
        where(active: true).lock.update_all(active: false)
        record = lock.find_or_initialize_by(
          fiscal_year: period.fetch('fyear'), apmon: period.fetch('apmon')
        )
        record.update!(
          start_date: period.fetch('sdate').to_date,
          end_date: period.fetch('edate').to_date,
          version: record.version || 1,
          active: true
        )
        record
      end
    end

    def increment_version!
      with_lock { increment!(:version) }
    end

    private

    def ordered_dates
      return if start_date.blank? || end_date.blank? || start_date <= end_date

      errors.add(:end_date, 'must be on or after start date')
    end
  end
end
