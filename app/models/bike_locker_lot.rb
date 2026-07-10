# frozen_string_literal: true

class BikeLockerLot < ApplicationRecord
  has_many :bike_lockers, foreign_key: :lot_id, inverse_of: :lot,
                          dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
end
