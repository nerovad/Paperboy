# frozen_string_literal: true

module Aim
  # One of AIM's budget units: a COA unit, or a whole agency when unit_id is
  # blank. Read by Aim::Units; set on Admin -> AIM's budget units.
  class EnabledUnit < Record
    validates :agency_id, presence: true
    validates :unit_id, uniqueness: { scope: :agency_id }

    scope :whole_agencies, -> { where(unit_id: nil) }
    scope :single_units, -> { where.not(unit_id: nil) }

    # Replaces the setting: whole agencies, then single units of the others.
    def self.replace!(agencies:, units:, by:)
      transaction do
        delete_all
        agencies.each { |agency| create!(agency_id: agency, enabled_by: by) }
        units.each { |agency, unit| create!(agency_id: agency, unit_id: unit, enabled_by: by) unless agencies.include?(agency) }
      end
    end
  end
end
