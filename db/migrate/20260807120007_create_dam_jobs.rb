# frozen_string_literal: true

# One run of anything the DAM does in the background — ingest, export, share
# delivery, or a custom workflow.
#
# Deliberately one table rather than one per job kind: the Jobs screen is a
# single status feed, and every kind needs the same six things (state, counts,
# timings, error, who asked). `job_type` distinguishes them; `workflow_id` is
# set only for workflow runs.
class CreateDamJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :dam_jobs do |t|
      # ingest | export | share | workflow
      t.string :job_type, null: false
      t.references :workflow, foreign_key: { to_table: :dam_workflows }

      # The asset or collection being operated on, when there is a single one.
      t.string :subject_type
      t.bigint :subject_id
      t.string :subject_label

      # queued | running | succeeded | failed | cancelled
      t.string :status, null: false, default: 'queued'
      t.integer :total_items, null: false, default: 0
      t.integer :processed_items, null: false, default: 0

      t.datetime :queued_at
      t.datetime :started_at
      t.datetime :finished_at

      t.text :error_message
      t.text :log

      t.string :created_by_id
      t.string :created_by_name
      t.timestamps
    end

    add_index :dam_jobs, :status
    add_index :dam_jobs, :job_type
    add_index :dam_jobs, :created_at
    add_index :dam_jobs, %i[subject_type subject_id]
  end
end
