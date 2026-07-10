# frozen_string_literal: true

class Unit < GsabssBase
  self.primary_key = 'unit_id'

  belongs_to :agency, foreign_key: 'agency_id', optional: true
  belongs_to :division, foreign_key: 'division_id', optional: true
  belongs_to :department, foreign_key: 'department_id', optional: true

  # Resolve a Unit from an Employee's Unit code. HCA uses a 5-level hierarchy
  # (Agency/Division/Department/Unit/Sub-Unit), so HCA employees often have
  # Employee.Unit pointing at a sub-unit code that doesn't exist in `units`.
  # When the direct lookup misses, fall back to `sub_units` and return the
  # parent Unit row — that's what every form prefill and ACL chain walks
  # against.
  def self.resolve_for_employee(emp)
    return nil unless emp&.unit.present?

    direct = find_by(unit_id: emp.unit)
    return direct if direct

    parent_id = SubUnit.where(sub_unit_id: emp.unit, agency_id: emp.agency).limit(1).pick(:unit_id)
    parent_id ? find_by(unit_id: parent_id) : nil
  end
end
