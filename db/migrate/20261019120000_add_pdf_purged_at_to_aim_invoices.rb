# frozen_string_literal: true

# When a deleted invoice's PDF was purged after the retention period (#170).
# The row stays as the record -- batch id, vendor, number, total, who deleted
# it and why, its history -- and the duplicate check still sees it. A second
# run, or a run after a crash, adds only what is missing.
class AddPdfPurgedAtToAimInvoices < ActiveRecord::Migration[8.1]
  def up
    add_column 'aim.invoices', :pdf_purged_at, :datetime unless column_exists?('aim.invoices', :pdf_purged_at)
  end

  def down
    remove_column 'aim.invoices', :pdf_purged_at if column_exists?('aim.invoices', :pdf_purged_at)
  end
end
