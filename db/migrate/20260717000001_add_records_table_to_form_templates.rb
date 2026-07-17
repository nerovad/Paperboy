# frozen_string_literal: true

# Opt-in flag for surfacing a form's submissions as a Records table (see
# FormBackedTable / the Records pillar). Off by default; admins toggle it per
# form in the template settings.
class AddRecordsTableToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :records_table, :boolean, default: false, null: false
  end
end
