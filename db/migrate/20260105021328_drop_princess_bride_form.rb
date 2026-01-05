class DropPrincessBrideForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :princess_bride_forms
  end
end
