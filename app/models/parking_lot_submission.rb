class ParkingLotSubmission < ApplicationRecord

  has_many :parking_lot_vehicles, dependent: :destroy
  accepts_nested_attributes_for :parking_lot_vehicles, allow_destroy: true

  STATUS_MAP = {
    0 => "submitted",
    1 => "manager_approved",
    2 => "denied",
    3 => "sent_to_security"
  }

  def status_label
    STATUS_MAP[status]
  end

  def submitted?
    status == 0
  end
end
