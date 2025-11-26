class DropVestForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :vest_forms
  end
end
