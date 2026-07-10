# frozen_string_literal: true

# app/models/employee.rb
class Employee < GsabssBase
  self.table_name = 'Employees'
  self.primary_key = 'id'

  # The GSABSS Employees table was renamed to snake_case columns; `id` is the
  # PK (previously EmployeeID). A small alias preserves the historical
  # employee_id accessor used throughout the app and form models.
  alias_attribute :employee_id, :id

  # Employees has a `type` column (job type / classification) that would
  # otherwise be treated as STI by Rails. Disable that.
  self.inheritance_column = nil

  has_many :employee_groups, foreign_key: 'EmployeeID', primary_key: 'id'
  # disable_joins: Employee_Groups/Groups live in the Paperboy DB while this
  # model lives in GSABSS — Rails cannot JOIN across connections.
  has_many :groups, through: :employee_groups, disable_joins: true

  # Helper method to check group membership
  def in_group?(name)
    groups.exists?(Group_Name: name)
  end

  # Helper to check multiple groups (user needs ANY of them)
  def in_any_group?(*group_names)
    groups.where(Group_Name: group_names).exists?
  end

  # Returns all employee IDs in the reporting chain beneath the given manager
  # (direct reports, their reports, etc.) Does NOT include the manager themselves.
  def self.subordinate_ids(manager_id)
    collected = []
    queue = [manager_id.to_s]

    while queue.any?
      direct_report_ids = where(supervisor_id: queue).pluck(:id).map(&:to_s)
      direct_report_ids -= collected # avoid cycles
      direct_report_ids -= [manager_id.to_s]
      break if direct_report_ids.empty?

      collected.concat(direct_report_ids)
      queue = direct_report_ids
    end

    collected
  end
end
