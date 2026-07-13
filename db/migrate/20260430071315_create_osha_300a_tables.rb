# frozen_string_literal: true

class CreateOsha300aTables < ActiveRecord::Migration[8.0]
  def up
    add_column :osha_reports, :restricted_duty_days, :integer

    create_table :osha_establishments do |t|
      t.string  :name,                  limit: 100, null: false
      t.string  :ein,                   limit: 9,   null: false
      t.string  :company_name,          limit: 100
      t.string  :street_address,        limit: 100, null: false
      t.string  :city,                  limit: 100, null: false
      t.string  :state,                 limit: 2,   null: false
      t.string  :zip,                   limit: 9,   null: false
      t.integer :naics_code,            null: false
      t.string  :industry_description,  limit: 300
      t.integer :size,                  null: false
      t.integer :establishment_type
      t.timestamps
    end
    add_index :osha_establishments, :name, unique: true

    create_table :osha_300a_entries do |t|
      t.references :osha_establishment, null: false, foreign_key: true
      t.integer    :year,                       null: false
      t.integer    :annual_average_employees,   null: false, default: 0
      t.bigint     :total_hours_worked,         null: false, default: 0
      t.string     :change_reason,              limit: 100
      t.datetime   :submitted_at
      t.timestamps
    end
    add_index :osha_300a_entries, %i[osha_establishment_id year], unique: true
  end

  def down
    drop_table :osha_300a_entries
    drop_table :osha_establishments
    remove_column :osha_reports, :restricted_duty_days
  end
end
