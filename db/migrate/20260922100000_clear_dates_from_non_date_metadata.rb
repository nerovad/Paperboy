# frozen_string_literal: true

# Dam::MetadataValue used to parse a date out of every value, whatever its
# field, and Time.zone.parse finds one in nearly any text: a keyword list
# became 1 July, a filename the year 201701. Those dates sat in date_value,
# where the before/after filters compare them. Only a date field should carry
# one, so the rest are cleared; the text itself is untouched.
class ClearDatesFromNonDateMetadata < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE dam_metadata_values SET date_value = NULL
      WHERE date_value IS NOT NULL
        AND field_key NOT IN (SELECT [key] FROM dam_metadata_fields WHERE field_type = 'date')
    SQL
  end

  def down
    # Nothing to restore: the cleared values were never dates.
  end
end
