# frozen_string_literal: true

class SyncSectionsTeleworkLogForm20260904164527 < ActiveRecord::Migration[7.1]
  def change
    create_table :telework_log_form_work_performeds do |t|
      t.bigint :telework_log_form_id, null: false
      t.text :work_performed
      t.timestamps
    end
    add_index :telework_log_form_work_performeds, :telework_log_form_id
    create_table :telework_log_form_hours do |t|
      t.bigint :telework_log_form_id, null: false
      t.integer :hours
      t.timestamps
    end
    add_index :telework_log_form_hours, :telework_log_form_id
  end
end
