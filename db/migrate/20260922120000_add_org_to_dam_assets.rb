# frozen_string_literal: true

# Where in the county an asset belongs, as the same four org ids
# form_visibility_grants and org_permissions store, edited with the shared org
# cascade. DAM access rules key on these; a free-text "Agency" metadata value
# could not be matched reliably.
class AddOrgToDamAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :dam_assets, :agency_id, :string
    add_column :dam_assets, :division_id, :string
    add_column :dam_assets, :department_id, :string
    add_column :dam_assets, :unit_id, :string
    add_index :dam_assets, :agency_id
  end
end
