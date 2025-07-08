class ParkingLotSubmission < ApplicationRecord
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
