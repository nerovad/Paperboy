class ParkingLotSubmission < ApplicationRecord

include PhoneNumberable

  has_many :parking_lot_vehicles, dependent: :destroy
  accepts_nested_attributes_for :parking_lot_vehicles, allow_destroy: true

  STATUS_MAP = {
    0 => "submitted",
    1 => "manager_approved",
    2 => "denied",
    3 => "sent_to_security"
  }

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }

  def status_label
    STATUS_MAP[status]
  end

  def submitted?
    status == 0
  end
  def manager_approved?
  status == 1
end

def denied?
  status == 2
end

def sent_to_security?
  status == 3
end
end
