class DropMinnesotaVikingsForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :minnesota_vikings_forms
  end
end
