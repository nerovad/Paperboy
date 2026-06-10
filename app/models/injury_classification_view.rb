# Read-only view that backs the "Injury Classifications" categorized dropdown
# source. One physical view holds many independent option-lists, keyed by
# injury_category_id (e.g. Report Type, Nature of Incident, Cause of Incident).
# Selected per-field in the form builder via FormField::DATA_SOURCES.
class InjuryClassificationView < ApplicationRecord
  self.table_name = "injury_classification_views"

  # Distinct categories as [label, id] pairs, ordered for display.
  def self.category_options
    order(:injury_category_id)
      .pluck(:injury_category_description, :injury_category_id)
      .uniq
  end
end
