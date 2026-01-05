class DropSonicTheHedgehogForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :sonic_the_hedgehog_forms
  end
end
