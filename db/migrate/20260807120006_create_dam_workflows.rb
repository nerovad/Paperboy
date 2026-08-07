# frozen_string_literal: true

# A registered piece of work the DAM can run over assets: transcodes, proxy
# generation, AI metadata extraction, exports.
#
# `runtime` and `entrypoint` are stored rather than assumed because these will
# not all be Ruby — AI metadata tooling is Python and engine work is C++. The
# runner shells out to the right interpreter for the runtime, so adding a
# language later is a new runtime value and a new invocation rule, not a new
# table.
class CreateDamWorkflows < ActiveRecord::Migration[8.0]
  def change
    create_table :dam_workflows do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description

      # ruby | python | cpp | shell
      t.string :runtime, null: false, default: 'ruby'
      t.string :entrypoint, comment: 'Script path or binary, relative to the workflow root'
      t.text :default_arguments

      # manual | on_ingest | scheduled — when the runner should raise a job.
      t.string :trigger, null: false, default: 'manual'
      t.string :schedule, comment: 'Cron expression, used when trigger is scheduled'

      # Which assets it is allowed to touch, so the UI can grey out a video
      # transcode sitting on a PDF. Empty means any.
      t.string :applies_to_media_types

      t.boolean :enabled, null: false, default: true
      t.string :created_by_id
      t.string :created_by_name
      t.datetime :last_run_at
      t.timestamps
    end

    add_index :dam_workflows, :slug, unique: true
    add_index :dam_workflows, :enabled
  end
end
