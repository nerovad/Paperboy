class DropZestyForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :zesty_forms
  end
end
