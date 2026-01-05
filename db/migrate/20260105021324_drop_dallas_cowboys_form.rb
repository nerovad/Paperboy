class DropDallasCowboysForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :dallas_cowboys_forms
  end
end
