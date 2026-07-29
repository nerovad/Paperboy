# frozen_string_literal: true

# app/models/agency.rb
class Agency < GsabssBase
  self.primary_key = 'agency_id'

  # `Employees.agency` carries a four-character personnel-system variant of the
  # agency code ("HCAV"), while every org table — agencies, divisions,
  # departments, units, sub_units — and the ACL's `org_permissions` rows use
  # the three-character id ("HCA"). Anything that matches an employee against
  # those tables has to reduce the code first, or it silently matches nothing.
  #
  # Returns the code unchanged when neither spelling exists (a handful of
  # employee agencies such as ISDV have no `agencies` row at all), so callers
  # still get a non-nil value to compare with.
  def self.normalize_id(code)
    key = code.to_s.strip.upcase
    return nil if key.blank?
    return key if exists?(agency_id: key)

    trimmed = key.sub(/V\z/, '')
    trimmed != key && exists?(agency_id: trimmed) ? trimmed : key
  end
end
