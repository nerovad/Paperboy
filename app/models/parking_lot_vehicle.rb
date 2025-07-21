class ParkingLotVehicle < ApplicationRecord
  belongs_to :parking_lot_submission

  def display_parking_lot
    parking_lot == "Other" && other_parking_lot.present? ? "Other: #{other_parking_lot}" : parking_lot
  end
end
