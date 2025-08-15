class LoaForm < ApplicationRecord
  self.table_name = "loa_forms"

  belongs_to :event, optional: true

  # New association to Employee (via EmployeeID)
  belongs_to :employee,
             primary_key: "EmployeeID",
             foreign_key: "employee_id",
             optional: true

  # Validations for new fields
  validates :employee_id, presence: true
  validates :employee_name, presence: true
end
