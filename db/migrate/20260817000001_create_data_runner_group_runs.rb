# frozen_string_literal: true

class CreateDataRunnerGroupRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :data_runner_group_runs do |t|
      t.string :run_id, null: false
      t.string :group_name, null: false
      t.string :status, null: false, default: 'queued'
      t.integer :total_count, null: false, default: 0
      t.integer :completed_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.string :current_dsl
      t.string :requested_by
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :data_runner_group_runs, :run_id, unique: true
    add_index :data_runner_group_runs, %i[group_name status]

    create_table :data_runner_group_run_items do |t|
      t.references :group_run, null: false, foreign_key: { to_table: :data_runner_group_runs }
      t.string :dsl_name, null: false
      t.string :dsl_slug, null: false
      t.string :status, null: false, default: 'pending'
      t.integer :position, null: false
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :data_runner_group_run_items, %i[group_run_id position],
              unique: true, name: 'idx_group_run_items_position'
  end
end
