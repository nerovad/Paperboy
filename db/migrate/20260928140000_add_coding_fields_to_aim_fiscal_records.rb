# frozen_string_literal: true

# Fields DocuShare's invoice properties carry that Fiscal has nowhere to type
# yet (Joshua's screenshots, 2026-09-28): the remit-to name, and the Fund,
# Department and Major Program coding.
class AddCodingFieldsToAimFiscalRecords < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.fiscal_records', :remit_to, :string, limit: 255
    add_column 'aim.fiscal_records', :fund, :string, limit: 20
    add_column 'aim.fiscal_records', :department, :string, limit: 20
    add_column 'aim.fiscal_records', :major_program, :string, limit: 20
  end
end
