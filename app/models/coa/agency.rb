# frozen_string_literal: true

module Coa
  class Agency < BaseRecord
    self.table_name = 'agencies'
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

    # Employee records sometimes carry a four-character personnel-system
    # variant (for example, HCAV) while the organization and account tables
    # use the three-character agency id (HCA).
    def self.normalize_id(code)
      key = code.to_s.strip.upcase
      return nil if key.blank?
      return key if exists?(agency_id: key)

      trimmed = key.sub(/V\z/, '')
      trimmed != key && exists?(agency_id: trimmed) ? trimmed : key
    end
  end
end
