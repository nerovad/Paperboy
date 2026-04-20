class ParkingLotVehicle < ApplicationRecord
  belongs_to :parking_lot_submission

  serialize :permit_type, coder: JSON, type: Array
  serialize :carpool_participants, coder: JSON, type: Array

  def display_parking_lot
    parking_lot == "Other" && other_parking_lot.present? ? "Other: #{other_parking_lot}" : parking_lot
  end
end
