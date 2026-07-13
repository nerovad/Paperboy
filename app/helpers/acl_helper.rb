# frozen_string_literal: true

module AclHelper
  # Seed option(s) for a contractor's currently-saved unit, so the select holds
  # the value on first render (before the JS cascade fetches the full list, and
  # as a no-JS fallback). Returns [] for a new contractor.
  def contractor_unit_options(contractor)
    return [] if contractor.unit.blank?

    unit = Unit.find_by(unit_id: contractor.unit)
    label = unit ? "#{unit.unit_id} - #{unit.long_name}" : contractor.unit
    [[label, contractor.unit]]
  end

  # Same idea for the saved supervisor (an Employee id).
  def contractor_supervisor_options(contractor)
    return [] if contractor.supervisor_id.blank?

    emp = Employee.find_by(id: contractor.supervisor_id)
    label = emp ? "#{emp.last_name}, #{emp.first_name} (#{emp.id})" : contractor.supervisor_id.to_s
    [[label, contractor.supervisor_id]]
  end
end
