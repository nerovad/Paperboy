# frozen_string_literal: true

class Osha300aEntry < ApplicationRecord
  self.table_name = 'osha_300a_entries'

  attribute :submitted_payload,   :json
  attribute :submission_response, :json

  belongs_to :osha_establishment

  def submitted?
    submitted_at.present?
  end

  validates :year, presence: true,
                   numericality: { only_integer: true, greater_than_or_equal_to: 1970 },
                   format: { with: /\A\d{4}\z/, message: 'must be a 4-digit year' }
  validates :year, uniqueness: { scope: :osha_establishment_id }
  validates :annual_average_employees,
            numericality: { only_integer: true, greater_than: 0, less_than: 25_000 }
  validates :total_hours_worked,
            numericality: { only_integer: true, greater_than: 0 }
  validate  :hours_per_employee_within_bounds
  validates :change_reason, length: { maximum: 100 }, allow_blank: true

  def hours_per_employee
    return nil if annual_average_employees.to_i.zero?

    total_hours_worked.to_f / annual_average_employees
  end

  private

  def hours_per_employee_within_bounds
    return if annual_average_employees.to_i.zero?

    ratio = hours_per_employee
    return unless ratio >= 8760

    errors.add(:total_hours_worked,
               "÷ annual_average_employees must be < 8760 (got #{ratio.round(1)})")
  end
end
