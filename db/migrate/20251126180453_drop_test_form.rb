class DropTestForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :test_forms
  end
end
