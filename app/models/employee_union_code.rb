class EmployeeUnionCode < ApplicationRecord
  validates :employee_id, presence: true, uniqueness: true
  validates :union_code, presence: true

  # Returns the employee's union code upcased, or "" when none is recorded.
  # Keyed by employee_id value because Employees lives in GSABSS (no FK / JOIN).
  def self.code_for(employee_id)
    return "" if employee_id.blank?

    where(employee_id: employee_id.to_s).limit(1).pick(:union_code).to_s.upcase
  end

  # Convenience lookup of the (cross-database) Employee this row refers to.
  def employee
    Employee.find_by(employee_id: employee_id)
  end
end
