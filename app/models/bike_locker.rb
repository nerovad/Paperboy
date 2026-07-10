class BikeLocker < ApplicationRecord
  belongs_to :lot, class_name: 'BikeLockerLot', foreign_key: :lot_id,
                   inverse_of: :bike_lockers

  enum :status, {
    available: 'available',
    assigned: 'assigned',
    reserved: 'reserved',
    out_of_service: 'out_of_service'
  }, default: :available

  validates :locker_number, presence: true,
                            uniqueness: { scope: :lot_id }

  # Free lockers for a lot, ready to feed the lot -> locker dropdown.
  scope :available_for_lot, lambda { |lot_id|
    available.where(lot_id: lot_id).order(:locker_number)
  }
end
