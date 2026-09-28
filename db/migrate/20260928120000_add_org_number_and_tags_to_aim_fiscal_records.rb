# frozen_string_literal: true

# Fiscal's tags are free text, not a fixed list (Joshua, 2026-09-28), and the
# report carries Org_Number, so Fiscal records one. The old single tag becomes
# the first of the tags.
class AddOrgNumberAndTagsToAimFiscalRecords < ActiveRecord::Migration[8.1]
  def up
    add_column 'aim.fiscal_records', :org_number, :string, limit: 20
    add_column 'aim.fiscal_records', :tags, :string, limit: 500
    execute 'UPDATE aim.fiscal_records SET tags = tag'
    remove_column 'aim.fiscal_records', :tag
  end

  def down
    add_column 'aim.fiscal_records', :tag, :string, limit: 40
    execute 'UPDATE aim.fiscal_records SET tag = LEFT(tags, 40)'
    remove_column 'aim.fiscal_records', :tags
    remove_column 'aim.fiscal_records', :org_number
  end
end
