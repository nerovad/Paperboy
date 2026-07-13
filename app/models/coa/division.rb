# frozen_string_literal: true

module Coa
  class Division < BaseRecord
    self.table_name = 'divisions'
    self.primary_key = %i[agency_id division_id]

    belongs_to :agency, foreign_key: :agency_id, inverse_of: :divisions

    has_many :departments, foreign_key: %i[agency_id division_id], inverse_of: :division
    has_many :units, foreign_key: %i[agency_id division_id], inverse_of: :division
  end
end
