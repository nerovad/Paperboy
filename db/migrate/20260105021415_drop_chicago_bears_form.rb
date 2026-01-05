class DropChicagoBearsForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :chicago_bears_forms
  end
end
