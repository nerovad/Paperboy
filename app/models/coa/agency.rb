# frozen_string_literal: true

module Coa
  class Agency < BaseRecord
    self.table_name = "agencies"
    self.primary_key = :agency_id

    has_many :activities, foreign_key: :agency_id, inverse_of: :agency
    has_many :departments, foreign_key: :agency_id, inverse_of: :agency
    has_many :divisions, foreign_key: :agency_id, inverse_of: :agency
    has_many :functions, foreign_key: :agency_id, inverse_of: :agency
    has_many :major_programs, foreign_key: :agency_id, inverse_of: :agency
    has_many :phases, foreign_key: :agency_id, inverse_of: :agency
    has_many :programs, foreign_key: :agency_id, inverse_of: :agency
    has_many :object_inferences, foreign_key: :agency_id, inverse_of: :agency
    has_many :sub_units, foreign_key: :agency_id, inverse_of: :agency
    has_many :tasks, foreign_key: :agency_id, inverse_of: :agency
    has_many :units, foreign_key: :agency_id, inverse_of: :agency
  end
end
