class ParkingLotVehicle < ApplicationRecord
  belongs_to :parking_lot_submission

  # This field is used in the form but is not stored in the DB
  attr_accessor :other_parking_lot

  before_validation :use_other_parking_lot_if_present

  private

  def use_other_parking_lot_if_present
    if parking_lot == "Other" && other_parking_lot.present?
      self.parking_lot = other_parking_lot
    end
  end
end
