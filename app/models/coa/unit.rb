# frozen_string_literal: true

module Coa
  class Unit < BaseRecord
    self.table_name = 'units'
    self.primary_key = %i[agency_id division_id department_id unit_id]

    belongs_to :agency, foreign_key: :agency_id, inverse_of: :units
    belongs_to :department, foreign_key: %i[agency_id division_id department_id], inverse_of: :units
    belongs_to :division, foreign_key: %i[agency_id division_id], inverse_of: :units

    has_many :sub_units, foreign_key: %i[agency_id unit_id], inverse_of: :unit
  end
end
