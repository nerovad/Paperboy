# frozen_string_literal: true

module Aim
  # One of AIM's budget units: a COA unit, or a whole agency when unit_id is
  # blank. Read by Aim::Units; set on Admin -> AIM's budget units.
  class EnabledUnit < Record
    validates :agency_id, presence: true
    validates :unit_id, uniqueness: { scope: :agency_id }

    scope :whole_agencies, -> { where(unit_id: nil) }
    scope :single_units, -> { where.not(unit_id: nil) }

    # Sets which of one agency's units AIM uses (#131, from its agency group's
    # page): the whole agency when that is every active unit, so the COA's
    # later units join too; otherwise those units one by one.
    def self.set_agency_units!(agency, units, by:)
      active = Coa::Unit.where(agency_id: agency, active: true).distinct.pluck(:unit_id)
      units = units.map(&:to_s).uniq & active
      transaction do
        where(agency_id: agency).delete_all
        if units.sort == active.sort then create!(agency_id: agency, enabled_by: by)
        else units.each { |unit| create!(agency_id: agency, unit_id: unit, enabled_by: by) }
        end
      end
    end

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
