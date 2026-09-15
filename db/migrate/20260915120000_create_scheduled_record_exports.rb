# frozen_string_literal: true

class CreateScheduledRecordExports < ActiveRecord::Migration[8.1]
  def change
    create_table :scheduled_record_exports do |t|
      t.string :employee_id, null: false
      # RegistryTable slug: "fleet", "osha-300-log", "form-<id>".
      t.string :table_slug, null: false, limit: 100

      # The grid view snapshot, JSON: search/filter_*/sort params and the
      # column layout the owner had when they scheduled it.
      t.text :view_params
      t.text :layout

      # Same schedule columns as scheduled_reports (see RecurringSchedule).
      t.string :frequency, null: false
      t.string :time_of_day, null: false
      t.integer :day_of_week
      t.integer :day_of_month
      t.boolean :enabled, null: false, default: true
      t.datetime :last_run_at
      t.datetime :next_run_at

      t.timestamps
    end

    add_index :scheduled_record_exports, %i[employee_id table_slug]
    add_index :scheduled_record_exports, %i[enabled next_run_at]
  end
end
