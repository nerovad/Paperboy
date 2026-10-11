# frozen_string_literal: true

# dbo.tasks was removed on Paperboy_Dev outside a migration. if_exists
# lets this apply there, and still drops the table on Stage and Prod.
class DropTasks < ActiveRecord::Migration[8.1]
  def up
    drop_table :tasks, if_exists: true
  end

  def down
    create_table :tasks, id: false do |t|
      t.string :agency_id, limit: 3, null: false
      t.string :task_id, limit: 4, null: false
      t.string :long_name, limit: 100, null: false
      t.string :short_name, limit: 50, null: false
    end
    execute 'ALTER TABLE tasks ADD PRIMARY KEY (agency_id, task_id)'
  end
end
