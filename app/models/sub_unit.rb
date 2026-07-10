# frozen_string_literal: true

class SubUnit < GsabssBase
  self.table_name = 'sub_units'
  # Composite PK (agency_id, unit_id, sub_unit_id); not exposed as a Rails PK
  # because nothing in the app needs to load a SubUnit by primary key.
end
