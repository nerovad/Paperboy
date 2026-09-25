# frozen_string_literal: true

module Aim
  # A budget unit someone works in AIM beyond their home unit, or their home
  # unit when they are its BU Admin. See item a.2 in docs/aim/aim_plan.md.
  class UserBudgetUnit < Record
    validates :employee_id, :budget_unit, presence: true
    validates :budget_unit, uniqueness: { scope: :employee_id }

    before_validation { self.budget_unit = budget_unit.to_s.strip }

    scope :for_person, ->(employee_id) { where(employee_id: employee_id) }
    scope :administered, -> { where(bu_admin: true, hidden: false) }
  end
end
