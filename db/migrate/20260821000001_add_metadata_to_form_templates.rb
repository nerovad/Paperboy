# frozen_string_literal: true

# Official metadata for finding a blank form to fill out.
#
# `tags` already held whatever free text an admin typed; these are the
# structured counterparts the sidebar's Advanced Search facets on — who owns
# the form, what kind of form it is, its official number, and a line of prose
# saying what it is for.
#
# The four org columns hold GSABSS codes, the same ones the org cascade picks
# elsewhere ("HCA", not "Health Care Agency"). They describe the form; they do
# not gate it. Who may see a form remains entirely the ACL's business.
class AddMetadataToFormTemplates < ActiveRecord::Migration[8.0]
  def change
    add_column :form_templates, :description, :string, limit: 500
    add_column :form_templates, :form_number, :string, limit: 30
    add_column :form_templates, :form_type, :string, limit: 50
    add_column :form_templates, :agency_id, :string, limit: 10
    add_column :form_templates, :division_id, :string, limit: 20
    add_column :form_templates, :department_id, :string, limit: 20
    add_column :form_templates, :unit_id, :string, limit: 20

    add_index :form_templates, :form_type
    add_index :form_templates, :agency_id
  end
end
