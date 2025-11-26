class DropYestyForm < ActiveRecord::Migration[8.0]
  def change
    drop_table :yesty_forms
  end
end
