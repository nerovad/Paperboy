class DropNewOrleansSaintsForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :new_orleans_saints_forms
  end
end
