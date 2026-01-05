class DropArizonaCardinalsForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :arizona_cardinals_forms
  end
end
