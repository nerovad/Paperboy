class DropLestyForm < ActiveRecord::Migration[8.0]
  def change
    drop_table :lesty_forms
  end
end
