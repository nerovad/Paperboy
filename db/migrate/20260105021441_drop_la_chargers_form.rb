class DropLaChargersForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :la_chargers_forms
  end
end
