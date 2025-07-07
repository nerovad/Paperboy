class AddUnitToParkingLotSubmissions < ActiveRecord::Migration[8.0]
  def change
    add_column :parking_lot_submissions, :unit, :string
  end
end
