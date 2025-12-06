# app/models/employee.rb
class Employee < ApplicationRecord
  self.table_name = 'Employees'
  self.primary_key = 'EmployeeID'

  has_many :employee_groups, foreign_key: 'EmployeeID'
  has_many :groups, through: :employee_groups
  
  # Helper method to check group membership
  def in_group?(group_name)
    groups.exists?(Group_Name: group_name)
  end
  
  # Helper to check multiple groups (user needs ANY of them)
  def in_any_group?(*group_names)
    groups.where(Group_Name: group_names).exists?
  end
end
