class SavedSearch < ApplicationRecord
  serialize :filters, coder: JSON

  validates :employee_id, presence: true
  validates :name, presence: true, uniqueness: { scope: :employee_id }

  scope :for_employee, ->(id) { where(employee_id: id) }
end
