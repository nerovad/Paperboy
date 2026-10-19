# frozen_string_literal: true

# SQL Dashboards (#129): a saved query, the dashboards that show queries as
# cards, and a log of every run and every change.
class CreateSqlDashboards < ActiveRecord::Migration[8.1]
  def change
    create_table :sql_dashboard_queries do |t|
      t.string :name, null: false
      t.text :description
      t.string :database_key, null: false
      t.string :chart_type, null: false
      t.text :statement, null: false
      t.string :created_by_id
      t.string :created_by_name
      t.string :updated_by_id
      t.string :updated_by_name
      t.timestamps
    end
    add_index :sql_dashboard_queries, :name

    create_table :sql_dashboards do |t|
      t.string :name, null: false
      t.text :description
      t.string :created_by_id
      t.string :created_by_name
      t.timestamps
    end
    add_index :sql_dashboards, :name

    create_table :sql_dashboard_cards do |t|
      t.references :sql_dashboard, null: false, foreign_key: true
      t.references :sql_dashboard_query, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :width, null: false, default: 'half'
      t.timestamps
    end

    # No foreign key to the query: the log outlives the query it describes.
    create_table :sql_dashboard_events do |t|
      t.bigint :sql_dashboard_query_id
      t.string :query_name
      t.string :action, null: false
      t.string :employee_id
      t.string :employee_name
      t.string :database_key
      t.text :statement
      t.integer :duration_ms
      t.integer :row_count
      t.text :error_message
      t.datetime :created_at, null: false
    end
    add_index :sql_dashboard_events, :sql_dashboard_query_id
    add_index :sql_dashboard_events, :created_at
  end
end
