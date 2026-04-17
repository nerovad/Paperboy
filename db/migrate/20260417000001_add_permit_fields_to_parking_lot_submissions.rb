class AddPermitFieldsToParkingLotSubmissions < ActiveRecord::Migration[8.0]
  def change
    add_column :parking_lot_submissions, :permit_type, :text
    add_column :parking_lot_submissions, :carpool_participants, :text
    add_column :parking_lot_submissions, :other_permit_type, :string, limit: 200
  end
end
