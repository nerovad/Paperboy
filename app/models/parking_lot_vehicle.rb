# frozen_string_literal: true

class ParkingLotVehicle < ApplicationRecord
  belongs_to :parking_lot_submission

  serialize :permit_type, coder: JSON, type: Array
  serialize :carpool_participants, coder: JSON, type: Array

  def display_parking_lot
    parking_lot == 'Other' && other_parking_lot.present? ? "Other: #{other_parking_lot}" : parking_lot
  end

  def display_permit_type
    Array(permit_type).reject(&:blank?).map do |type|
      type == 'Other' && other_permit_type.present? ? "Other: #{other_permit_type}" : type
    end.join(', ')
  end
end
