class AddDelegatedApproverToParkingLotSubmissions < ActiveRecord::Migration[7.0]
  def change
    add_column :parking_lot_submissions, :delegated_approver_id, :string
    add_column :parking_lot_submissions, :delegated_approver_email, :string
    add_column :parking_lot_submissions, :delegated_approved_by, :string
    add_column :parking_lot_submissions, :delegated_approved_at, :datetime
  end
end
