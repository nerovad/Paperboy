class DropSeattleSeahawksForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :seattle_seahawks_forms
  end
end
