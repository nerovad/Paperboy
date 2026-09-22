# frozen_string_literal: true

# A collection brought over from another system remembers which one it was,
# so a second import finds it again. By name would not do: ResourceSpace has
# two collections called "Murals", and matching on the name would pour both
# into one.
class AddExternalRefToDamCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :dam_collections, :external_ref, :string
    add_index :dam_collections, :external_ref, unique: true, where: 'external_ref IS NOT NULL'
  end
end
