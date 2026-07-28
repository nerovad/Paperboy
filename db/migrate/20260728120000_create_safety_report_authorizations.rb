# frozen_string_literal: true

class CreateSafetyReportAuthorizations < ActiveRecord::Migration[8.0]
  # The Safety Reporting authorization console. Far simpler than the
  # parking/badge/key console: a Safety Report only needs to know which safety
  # officer covers the submitter's org node, so a row is just
  # (division_id -> employee_id). No service types, budget units or locations.
  #
  # division_id holds a GSABSS `divisions.division_id` under agency HCA. HCA's
  # own vocabulary reverses the middle two org levels, so this is what they call
  # a "department" — see OrgLabels. The column keeps the database's name.
  def up
    return if table_exists?(:safety_report_authorizations)

    create_table :safety_report_authorizations do |t|
      t.string :employee_id, null: false
      t.string :division_id, null: false
      t.string :authorized_by

      t.timestamps
    end

    add_index :safety_report_authorizations, :division_id
    add_index :safety_report_authorizations, %i[employee_id division_id],
              unique: true, name: 'index_safety_report_authorizations_on_employee_and_division'
  end

  def down
    drop_table :safety_report_authorizations if table_exists?(:safety_report_authorizations)
  end
end
