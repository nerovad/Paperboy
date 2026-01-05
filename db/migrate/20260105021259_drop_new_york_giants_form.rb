class DropNewYorkGiantsForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :new_york_giants_forms
  end
end
