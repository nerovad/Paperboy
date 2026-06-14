class AddApproverIdToParkingLotSubmissions < ActiveRecord::Migration[8.0]
  def change
    # Brings parking onto the form-builder's dynamic inbox path (which keys off
    # approver_id alongside group/authorization routing scopes), so the form's
    # UI routing steps actually execute.
    add_column :parking_lot_submissions, :approver_id, :string
  end
end
