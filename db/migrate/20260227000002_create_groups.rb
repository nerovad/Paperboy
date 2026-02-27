class CreateGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :groups do |t|
      t.string :group_name, limit: 100, null: false
      t.string :description, limit: 500
      t.datetime :created_at, default: -> { "CURRENT_TIMESTAMP" }
    end
  end
end
