# app/models/employee_group.rb
class EmployeeGroup < ApplicationRecord
  self.table_name = 'Employee_Groups'
  
  belongs_to :employee, foreign_key: 'EmployeeID'
  belongs_to :group, foreign_key: 'GroupID'
end
