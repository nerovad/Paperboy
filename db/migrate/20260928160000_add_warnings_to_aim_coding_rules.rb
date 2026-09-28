# frozen_string_literal: true

# A rule loaded or saved over the COA's objection keeps the objection in
# sight (Joshua, 2026-09-28: "there are always exceptions").
class AddWarningsToAimCodingRules < ActiveRecord::Migration[8.1]
  def change
    add_column 'aim.coding_rules', :warnings, :text
  end
end
