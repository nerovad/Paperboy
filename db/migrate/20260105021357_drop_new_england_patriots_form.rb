class DropNewEnglandPatriotsForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :new_england_patriots_forms
  end
end
