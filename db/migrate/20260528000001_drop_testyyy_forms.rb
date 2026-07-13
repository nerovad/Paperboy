# frozen_string_literal: true

class DropTestyyyForms < ActiveRecord::Migration[8.0]
  def up
    drop_table :testyyy_forms, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
