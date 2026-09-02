# frozen_string_literal: true

class CreateAwayPeriods < ActiveRecord::Migration[8.0]
  def change
    create_table :away_periods do |t|
      t.string :employee_id, null: false
      t.string :delegate_id, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.timestamps
    end

    add_index :away_periods, %i[employee_id starts_on ends_on], name: 'index_away_periods_on_employee_and_dates'
    add_index :away_periods, :ends_on
  end
end
