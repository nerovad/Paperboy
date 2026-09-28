# frozen_string_literal: true

# The approval stamp (item e, brought into f by Joshua 2026-09-28): when the
# stamped copy was written, or why it could not be.
class AddStampToAimFiscalRecords < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.fiscal_records', :stamped_at, :datetime
    add_column 'aim.fiscal_records', :stamp_error, :string, limit: 500
  end
end
