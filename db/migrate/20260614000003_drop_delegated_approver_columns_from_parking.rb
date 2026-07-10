# frozen_string_literal: true

class DropDelegatedApproverColumnsFromParking < ActiveRecord::Migration[8.0]
  def change
    # The delegated-approver (Sean Payne) flow is now a normal form-builder
    # routing step, so these bespoke columns are dead.
    remove_column :parking_lot_submissions, :delegated_approver_id, :string
    remove_column :parking_lot_submissions, :delegated_approver_email, :string
    remove_column :parking_lot_submissions, :delegated_approved_by, :string
    remove_column :parking_lot_submissions, :delegated_approved_at, :datetime
  end
end
