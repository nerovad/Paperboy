class DropLaRamsForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :la_rams_forms
  end
end
