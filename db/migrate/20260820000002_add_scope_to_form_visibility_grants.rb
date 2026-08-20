# frozen_string_literal: true

# Makes a visibility grant granular: which surfaces it widens (Inbox,
# Submissions or both) and, optionally, which corner of the organization the
# submissions have to come from.
class AddScopeToFormVisibilityGrants < ActiveRecord::Migration[8.0]
  def change
    add_column :form_visibility_grants, :applies_to, :string, default: 'both', null: false
    add_column :form_visibility_grants, :agency_id, :string
    add_column :form_visibility_grants, :division_id, :string
    add_column :form_visibility_grants, :department_id, :string
    add_column :form_visibility_grants, :unit_id, :string
  end
end
