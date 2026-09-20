# frozen_string_literal: true

# A metadata value was capped at 450 characters because the column sat in an
# index, and SQL Server will not key on more than that. Real libraries do not
# fit: ResourceSpace keyword lists run past 600 characters routinely, and four
# resources in the first three hundred imported failed on it.
#
# Dam::MetadataFilter only ever compares this column with LIKE or equality,
# neither of which needs the index, so the column becomes text and the index
# narrows to the field key it is nearly always filtered by first.
class WidenDamMetadataValues < ActiveRecord::Migration[8.1]
  def up
    remove_index :dam_metadata_values, %i[field_key value],
                 name: 'index_dam_metadata_values_on_field_key_and_value'
    change_column :dam_metadata_values, :value, :text
    add_index :dam_metadata_values, :field_key
  end

  def down
    remove_index :dam_metadata_values, :field_key
    change_column :dam_metadata_values, :value, :string, limit: 450
    add_index :dam_metadata_values, %i[field_key value],
              name: 'index_dam_metadata_values_on_field_key_and_value'
  end
end
