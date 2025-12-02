class DropFindingNemo < ActiveRecord::Migration[8.0]
  def change
    drop_table :finding_nemos
  end
end
