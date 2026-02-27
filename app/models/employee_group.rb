# app/models/employee_group.rb
class EmployeeGroup < ApplicationRecord
  belongs_to :employee
  belongs_to :group
end
