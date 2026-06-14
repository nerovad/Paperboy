# app/models/employee_group.rb
class EmployeeGroup < ApplicationRecord
  self.table_name = 'Employee_Groups'

  # Column aliases: MSSQL PascalCase → Rails snake_case
  alias_attribute :employee_id, :EmployeeID
  alias_attribute :group_id, :GroupID
  alias_attribute :assigned_at, :Assigned_At
  alias_attribute :assigned_by, :Assigned_By

  # A membership references either a GSABSS Employee or a Paperboy Contractor —
  # both live in the same id space (contractor ids are seeded at 1,000,000,000 so
  # they never collide). The association is optional because contractors aren't
  # Employees; integrity is enforced instead by `member_exists`, which still
  # rejects ids that match neither.
  belongs_to :employee, foreign_key: 'EmployeeID', primary_key: 'id', optional: true
  belongs_to :group, foreign_key: 'GroupID'

  validate :member_exists

  private

  def member_exists
    return if employee_id.blank?
    return if Employee.exists?(id: employee_id) || Contractor.exists?(id: employee_id)
    errors.add(:employee_id, "must reference an employee or contractor")
  end
end
