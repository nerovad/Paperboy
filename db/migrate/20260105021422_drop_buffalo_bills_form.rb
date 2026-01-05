class DropBuffaloBillsForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :buffalo_bills_forms
  end
end
