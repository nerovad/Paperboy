class DropSuperMarioForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :super_mario_forms
  end
end
