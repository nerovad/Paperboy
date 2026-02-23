class HelpTicket < ApplicationRecord
  enum :status, { open: 0, closed: 1 }

  scope :for_employee, ->(eid) { where(employee_id: eid.to_s) }

  validates :subject, :description, :employee_id, presence: true
end
