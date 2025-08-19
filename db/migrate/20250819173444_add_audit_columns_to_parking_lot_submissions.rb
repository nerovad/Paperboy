class AddAuditColumnsToParkingLotSubmissions < ActiveRecord::Migration[8.0]
  def change
    add_column :parking_lot_submissions, :approved_by, :string
    add_column :parking_lot_submissions, :approved_at, :datetime
    add_column :parking_lot_submissions, :denied_by, :string
    add_column :parking_lot_submissions, :denied_at, :datetime
    add_column :parking_lot_submissions, :denial_reason, :text
    add_column :parking_lot_submissions, :supervisor_email, :string
  end
end
