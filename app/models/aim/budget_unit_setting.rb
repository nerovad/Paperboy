# frozen_string_literal: true

module Aim
  # A budget unit's own AIM settings (#131), set on its agency group's
  # BUs & People tab. So far the high-dollar second approval: an invoice over
  # second_approval_over goes, after its first approval, to the second
  # approver's queue.
  class BudgetUnitSetting < Record
    before_validation do
      self.agency_id = agency_id.to_s.strip.upcase
      self.budget_unit = budget_unit.to_s.strip
    end

    validates :agency_id, :budget_unit, presence: true
    validates :budget_unit, uniqueness: { scope: :agency_id }
    validates :second_approval_over, numericality: { greater_than: 0 }, allow_nil: true
    validate :amount_and_approver_together

    def self.for_unit(agency, unit) = find_by(agency_id: agency.to_s.upcase, budget_unit: unit.to_s)

    def second_approval? = second_approval_over.present? && second_approver_employee_id.present?

    def second_approver_name = Aim::Invoice.employee_name(second_approver_employee_id)

    private

    def amount_and_approver_together
      return if second_approval_over.present? == second_approver_employee_id.present?

      errors.add(:base, 'A second approval needs both an amount and a second approver')
    end
  end
end
