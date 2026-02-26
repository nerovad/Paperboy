class DropTestFormForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :test_form_forms
  end
end
