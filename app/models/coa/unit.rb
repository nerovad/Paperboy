# frozen_string_literal: true

module Coa
  class Unit < BaseRecord
    self.table_name = 'units'
    self.primary_key = %i[agency_id division_id department_id unit_id]

    belongs_to :agency, foreign_key: :agency_id, inverse_of: :units
    belongs_to :department, foreign_key: %i[agency_id division_id department_id], inverse_of: :units
    belongs_to :division, foreign_key: %i[agency_id division_id], inverse_of: :units

    has_many :sub_units, foreign_key: %i[agency_id unit_id], inverse_of: :unit

    # HCA employee records may put a sub-unit code in employees.unit. Resolve
    # that code to its parent account hierarchy unit when no direct unit row
    # exists.
    def self.resolve_for_employee(employee)
      return nil unless employee&.unit.present?

      agency_id = Coa::Agency.normalize_id(employee.agency)
      direct = find_by(agency_id: agency_id, unit_id: employee.unit)
      return direct if direct

      parent_id = Coa::SubUnit.where(
        agency_id: agency_id,
        sub_unit_id: employee.unit
      ).limit(1).pick(:unit_id)
      parent_id ? find_by(agency_id: agency_id, unit_id: parent_id) : nil
    end
  end
end
