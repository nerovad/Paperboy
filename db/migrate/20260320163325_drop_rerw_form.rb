class DropRerwForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :rerw_forms
  end
end
