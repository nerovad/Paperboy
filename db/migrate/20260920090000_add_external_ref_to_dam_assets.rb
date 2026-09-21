# frozen_string_literal: true

# An asset imported from another system remembers which record it came from,
# so a second import updates what changed instead of making everything twice.
# Scoped to the location, because two locations may each mirror a library of
# their own and their refs mean nothing to each other.
class AddExternalRefToDamAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :dam_assets, :external_ref, :string
    add_index :dam_assets, %i[storage_location_id external_ref], unique: true,
                                                                 where: 'external_ref IS NOT NULL',
                                                                 name: 'index_dam_assets_on_location_and_external_ref'
  end
end
