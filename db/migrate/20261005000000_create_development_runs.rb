# frozen_string_literal: true

class CreateDevelopmentRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :development_runs do |t|
      t.string :script_key, null: false
      t.string :script_label, null: false
      t.text :command_json, null: false
      t.string :requested_by, null: false
      t.string :status, null: false, default: 'queued'
      t.text :output
      t.integer :exit_status
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :development_runs, :status
    add_index :development_runs, :created_at
  end
end
