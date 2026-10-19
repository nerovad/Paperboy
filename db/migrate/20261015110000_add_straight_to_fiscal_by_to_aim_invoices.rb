# frozen_string_literal: true

# Straight to Fiscal (#131): who uploaded an invoice for Fiscal, skipping a
# person's approval. Read by the AI or typed in, it is approved in their name
# (Aim::StraightToFiscalJob) and lands with Fiscal.
class AddStraightToFiscalByToAimInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.invoices', :straight_to_fiscal_by, :string, limit: 255
  end
end
