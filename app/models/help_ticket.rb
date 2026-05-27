class HelpTicket < ApplicationRecord
  enum :status, { open: "open", closed: "closed" }, default: :open

  scope :for_employee, ->(eid) { where(employee_id: eid.to_s) }

  validates :subject, :description, :employee_id, presence: true
end
