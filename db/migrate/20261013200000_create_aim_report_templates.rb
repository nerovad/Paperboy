# frozen_string_literal: true

# Fiscal report templates (#131): named report layouts an agency group saves
# and picks from when downloading, beside its own Default. Columns, their
# order and headers as JSON in export_columns, as on aim.agency_groups.
#
# No database foreign keys and explicit index names: see
# test/lib/aim/schema_conventions_test.rb.
class CreateAimReportTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table 'aim.report_templates' do |t|
      t.bigint :agency_group_id, null: false
      t.string :name, limit: 100, null: false
      t.string :export_format, limit: 10, default: 'csv', null: false
      t.text :export_columns
      t.string :updated_by, limit: 255
      t.timestamps
    end
    add_index 'aim.report_templates', %i[agency_group_id name], unique: true,
                                                                name: 'index_aim_report_templates_on_group_and_name'
  end
end
