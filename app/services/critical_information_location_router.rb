# frozen_string_literal: true

# app/services/critical_information_location_router.rb
#
# Routes a Critical Information Report to an incident manager by its
# "Where: Location" field.
#
# This used to be a hardcoded LOCATION_MANAGER_MAP of ~350 abbreviated address
# patterns matched against the form's location with a city/street-number fuzzy
# comparison. Both sides were hand-maintained lists that drifted, so 41 of the
# form's 212 sites matched nothing and routed nowhere, and 11 matched two
# managers and silently took whichever the hash yielded first.
#
# The mapping now lives in critical_information_authorizations, editable in the
# CIR authorization console, keyed on the exact catalogue value the form
# submits. The map's contents were migrated into that table — see
# CreateCriticalInformationAuthorizations.
class CriticalInformationLocationRouter
  def self.find_manager_for_location(location)
    CriticalInformationAuthorization.manager_id_for_location(location)
  end

  # Employee id => manager name, for every site that currently has one. Lets the
  # form label each location with its manager in one pair of queries rather than
  # one per option.
  def self.manager_names_by_id
    ids = CriticalInformationAuthorization.distinct.pluck(:employee_id).compact
    return {} if ids.empty?

    Employee.where(employee_id: ids)
            .pluck(:employee_id, :first_name, :last_name)
            .each_with_object({}) { |(id, first, last), names| names[id.to_s] = "#{first} #{last}".strip }
  end

  # location => manager name, for the sites that have one.
  def self.manager_names_by_location
    names = manager_names_by_id
    CriticalInformationAuthorization.pluck(:location, :employee_id)
                                    .each_with_object({}) do |(location, employee_id), by_location|
      name = names[employee_id.to_s]
      by_location[location] = name if name.present?
    end
  end
end
