# app/models/authorization_manager.rb
class AuthorizationManager < ApplicationRecord
  validates :employee_id, presence: true
  validates :department_id, presence: true
  validates :employee_id, uniqueness: { scope: :department_id }
  
  def employee
    Employee.find_by(employee_id: employee_id)
  end
  
  def department
    Department.find_by(department_id: department_id)
  end
end
