class DropCarpoolForm < ActiveRecord::Migration[8.0]
  def change
    drop_table :carpool_forms
  end
end
