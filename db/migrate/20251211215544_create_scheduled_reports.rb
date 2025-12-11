class CreateScheduledReports < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduled_reports do |t|
      t.string :employee_id, null: false
      t.string :form_type, null: false
      t.string :format, null: false, default: 'csv'
      t.string :status_filter, null: true
      
      # Scheduling
      t.string :frequency, null: false  # daily, weekly, monthly
      t.string :time_of_day, null: false  # "23:30"
      t.integer :day_of_week, null: true  # 0-6 (Sunday-Saturday) for weekly
      t.integer :day_of_month, null: true  # 1-31 for monthly
      
      # Date range type
      t.string :date_range_type, null: false  # last_7_days, last_30_days, last_month, etc.
      
      # Status
      t.boolean :enabled, default: true, null: false
      t.datetime :last_run_at
      t.datetime :next_run_at
      
      t.timestamps
    end
    
    add_index :scheduled_reports, :employee_id
    add_index :scheduled_reports, :enabled
    add_index :scheduled_reports, :next_run_at
  end
end
