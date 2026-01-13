# app/models/task_reassignment.rb

class TaskReassignment < ApplicationRecord
  # Polymorphic association - can belong to any task type
  belongs_to :task, polymorphic: true

  # Validations
  validates :task_type, presence: true
  validates :task_id, presence: true
  validates :from_employee_id, presence: true
  validates :to_employee_id, presence: true
  validates :reassigned_by_id, presence: true

  # Helper methods to fetch employee records for display
  def from_employee
    @from_employee ||= Employee.find_by(EmployeeID: from_employee_id)
  end

  def to_employee
    @to_employee ||= Employee.find_by(EmployeeID: to_employee_id)
  end

  def reassigned_by_employee
    @reassigned_by_employee ||= Employee.find_by(EmployeeID: reassigned_by_id)
  end
end
