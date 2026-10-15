# frozen_string_literal: true

# Manual Data Entry Needed (#131): an invoice uploaded without the AI, or sent
# to someone's queue by an AIM Admin to be typed in by hand. Cleared once the
# fields a user needs are filled in.
class AddManualEntryToAimInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.invoices', :manual_entry, :boolean, default: false, null: false
  end
end
