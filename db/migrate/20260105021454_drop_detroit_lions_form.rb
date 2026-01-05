class DropDetroitLionsForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :detroit_lions_forms
  end
end
