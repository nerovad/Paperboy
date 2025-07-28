class Unit < ApplicationRecord
  self.table_name = 'dbo.sub_units'
  self.primary_key = 'subunit_id'

  belongs_to :agency, foreign_key: 'agency_id', optional: true
  # If unit_id references a parent unit:
  # belongs_to :parent_unit, class_name: 'Unit', foreign_key: 'unit_id', optional: true
end
