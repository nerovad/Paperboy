class DropLoaForms < ActiveRecord::Migration[8.0]
  def change
    drop_table :loa_forms
  end
end
