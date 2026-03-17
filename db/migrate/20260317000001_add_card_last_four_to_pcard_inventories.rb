class AddCardLastFourToPcardInventories < ActiveRecord::Migration[8.0]
  def change
    add_column :pcard_inventories, :card_last_four, :string, limit: 4

    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE pcard_inventories
          SET card_last_four = RIGHT(card_number, 4)
          WHERE card_number IS NOT NULL AND LEN(card_number) >= 4
        SQL
      end
    end
  end
end
