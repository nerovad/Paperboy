class DropToyStories < ActiveRecord::Migration[7.1]
  def change
    drop_table :toy_stories
  end
end
