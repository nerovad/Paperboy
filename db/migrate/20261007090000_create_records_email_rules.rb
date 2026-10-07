# frozen_string_literal: true

# Emails from a Records grid, set up by the table's editors: standing rules
# that send the rows meeting a condition (RecordsEmailRule), the contacts a
# rule that splits by a column sends each value's rows to
# (RecordsEmailContact), and a log of everything sent (RecordsEmailDelivery).
class CreateRecordsEmailRules < ActiveRecord::Migration[8.1]
  def change
    create_table :records_email_rules do |t|
      t.string :table_slug, null: false, limit: 100
      t.string :column_name, null: false
      t.string :operator, null: false
      t.string :value
      t.string :label, null: false
      t.text :message, null: false
      t.string :split_column
      t.text :recipients
      t.string :employee_id, null: false
      t.string :frequency, null: false
      t.string :time_of_day, null: false
      t.integer :day_of_week
      t.integer :day_of_month
      t.boolean :enabled, null: false, default: true
      t.datetime :last_run_at
      t.datetime :next_run_at
      t.timestamps
    end
    add_index :records_email_rules, :table_slug
    add_index :records_email_rules, %i[enabled next_run_at]

    create_table :records_email_contacts do |t|
      t.string :table_slug, null: false, limit: 100
      t.string :column_name, null: false, limit: 100
      t.string :match_value, null: false, limit: 200
      t.string :email, null: false, limit: 255
      t.integer :created_by_employee_id
      t.timestamps
    end
    add_index :records_email_contacts, %i[table_slug column_name match_value email], unique: true,
                                                                                     name: 'index_records_email_contacts_unique'

    create_table :records_email_deliveries do |t|
      t.string :table_slug, null: false, limit: 100
      t.bigint :records_email_rule_id
      t.string :subject
      t.text :recipients
      t.integer :row_count, null: false, default: 0
      t.string :group_value
      t.string :sent_by_employee_id
      t.datetime :created_at, null: false
    end
    add_index :records_email_deliveries, %i[table_slug created_at]
    add_index :records_email_deliveries, :records_email_rule_id
  end
end
