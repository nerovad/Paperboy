module Coa
  class SubUnit < BaseRecord
    self.table_name = "sub_units"
    self.primary_key = %i[agency_id unit_id sub_unit_id]

    belongs_to :agency, foreign_key: :agency_id, inverse_of: :sub_units
    belongs_to :unit, foreign_key: %i[agency_id unit_id], inverse_of: :sub_units
  end
end
