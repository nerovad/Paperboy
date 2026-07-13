# frozen_string_literal: true

module Coa
  class MajorProgram < BaseRecord
    self.table_name = "major_programs"
    self.primary_key = %i[agency_id major_program_id]

    belongs_to :agency, foreign_key: :agency_id, inverse_of: :major_programs
    has_many :programs,
             foreign_key: %i[agency_id major_program_id],
             inverse_of: :major_program
  end
end
