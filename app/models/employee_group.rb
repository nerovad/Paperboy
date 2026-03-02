# app/models/employee_group.rb
class EmployeeGroup < ApplicationRecord
  self.table_name = 'Employee_Groups'

  # Column aliases: MSSQL PascalCase → Rails snake_case
  alias_attribute :employee_id, :EmployeeID
  alias_attribute :group_id, :GroupID
  alias_attribute :assigned_at, :Assigned_At
  alias_attribute :assigned_by, :Assigned_By

  belongs_to :employee, foreign_key: 'EmployeeID', primary_key: 'EmployeeID'
  belongs_to :group, foreign_key: 'GroupID'
end
