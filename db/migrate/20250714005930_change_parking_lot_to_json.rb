class ChangeParkingLotToJson < ActiveRecord::Migration[8.0]
  def change
  change_column :parking_lot_submissions, :parking_lot, :json
end 
end
