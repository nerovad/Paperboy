# frozen_string_literal: true

# app/models/authorized_approver.rb
class AuthorizedApprover < ApplicationRecord
  # Locations are chosen from the buildings table and can contain commas, so we
  # store the multi-select as a JSON array rather than a comma-joined string.
  serialize :locations, coder: JSON, type: Array

  validates :employee_id, presence: true
  validates :department_id, presence: true
  validates :service_type, presence: true, inclusion: { in: %w[P E V C K] }
  validates :key_type, inclusion: { in: %w[1 2 3 4 5 6 7] }, if: -> { service_type == 'K' }
  validates :employee_id, uniqueness: {
    scope: %i[department_id service_type key_type],
    message: 'is already authorized for this service type in this department'
  }

  SERVICE_TYPES = {
    'P' => 'Parking Permits',
    'E' => 'Employee Identification Badges',
    'V' => 'Volunteer ID Badges',
    'C' => 'Vendor ID Badges',
    'K' => 'Facility Keys and Security Access'
  }.freeze

  KEY_TYPES = {
    '1' => 'Master Keys',
    '2' => 'Access Cards',
    '3' => 'Site Keys',
    '4' => 'Area / Room Keys',
    '5' => 'Perimeter Fence Gates',
    '6' => 'Equipment Closet Keys',
    '7' => 'File/Desk/Storage Cabinet Keys'
  }.freeze

  def employee
    Employee.find_by(employee_id: employee_id)
  end

  def department
    Department.find_by(department_id: department_id)
  end

  def service_type_label
    SERVICE_TYPES[service_type] || service_type
  end

  def key_type_label
    KEY_TYPES[key_type] || key_type
  end

  # Find approvers for a given department and service type
  def self.approvers_for(department_id:, service_type:)
    where(department_id: department_id, service_type: service_type).pluck(:employee_id).uniq
  end

  # Find approvers for a given department, service type, and budget unit.
  # all_budget_units matches any unit; otherwise the unit must appear in the
  # approver's comma-separated budget_units list.
  def self.approver_for_unit(department_id:, service_type:, unit_id:)
    candidates = where(department_id: department_id, service_type: service_type)
    unit_str = unit_id.to_s

    candidates.select do |a|
      a.all_budget_units? || a.budget_units.to_s.split(',').map(&:strip).include?(unit_str)
    end.map(&:employee_id).uniq
  end

  # True when this authorization row covers the given budget unit. Mirrors the
  # expansion used by authorized_unit_ids_for: all_budget_units covers any unit
  # in the approver's department; otherwise the unit must be listed explicitly.
  def covers_unit?(unit_id)
    if all_budget_units?
      Unit.exists?(unit_id: unit_id, department_id: department_id)
    else
      budget_units.to_s.split(',').map(&:strip).include?(unit_id.to_s)
    end
  end

  # Every employee_id eligible to approve the given service type for a budget
  # unit, regardless of which department the approver is configured under. This
  # is the inverse of authorized_unit_ids_for and matches the inbox's
  # authorization visibility exactly.
  def self.approver_ids_covering_unit(service_type:, unit_id:)
    where(service_type: service_type).select { |a| a.covers_unit?(unit_id) }.map(&:employee_id).uniq
  end

  # Returns every unit_id this employee is authorized to approve for the given
  # service type. all_budget_units expands to all units in the approver's
  # department; otherwise the explicit budget_units list is used.
  def self.authorized_unit_ids_for(employee_id:, service_type:)
    rows = where(employee_id: employee_id, service_type: service_type)
    return [] if rows.empty?

    unit_ids = Set.new
    rows.each do |a|
      if a.all_budget_units?
        Unit.where(department_id: a.department_id).pluck(:unit_id).each { |u| unit_ids << u.to_s }
      else
        a.budget_units.to_s.split(',').map(&:strip).each { |u| unit_ids << u if u.present? }
      end
    end
    unit_ids.to_a
  end
end
