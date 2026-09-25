# frozen_string_literal: true

module Aim
  # A budget unit someone works in AIM beyond their home unit, or their home
  # unit when they are its BU Admin. See item a.2 in docs/aim/aim_plan.md.
  class UserBudgetUnit < Record
    validates :employee_id, :budget_unit, presence: true
    validates :budget_unit, uniqueness: { scope: :employee_id }

    before_validation { self.budget_unit = budget_unit.to_s.strip }

    scope :for_person, ->(employee_id) { where(employee_id: employee_id) }
    scope :administered, -> { where(bu_admin: true) }

    # The units AIM offers when granting a BU: GSA's active ones, as
    # [["4641 · Document Management", "4641"], ...].
    def self.unit_options
      Coa::Unit.where(agency_id: 'GSA', active: true).order(:unit_id).pluck(:unit_id, :long_name)
               .map { |unit, name| ["#{unit} · #{name.to_s.titleize}", unit] }
    end
  end
end
