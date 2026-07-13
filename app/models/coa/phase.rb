# frozen_string_literal: true

module Coa
  class Phase < BaseRecord
    self.table_name = "phases"
    self.primary_key = %i[agency_id phase_id]

    belongs_to :agency, foreign_key: :agency_id, inverse_of: :phases
  end
end
