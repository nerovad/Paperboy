class DropJungleBookForm < ActiveRecord::Migration[7.1]
  def change
    drop_table :jungle_book_forms
  end
end
