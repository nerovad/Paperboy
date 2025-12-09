class DropJacksonvilleJaguarsForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :jacksonville_jaguars_forms
  end
end
