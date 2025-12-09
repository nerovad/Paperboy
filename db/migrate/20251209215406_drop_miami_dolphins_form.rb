class DropMiamiDolphinsForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :miami_dolphins_forms
  end
end
