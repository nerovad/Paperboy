# frozen_string_literal: true

module Aim
  # A BU ticked into a custom agency group (#131), which takes it out of its
  # agency's own group. Agency groups keep no rows: they hold every unit of
  # their agency that no custom group has, the COA's later units included.
  class AgencyGroupUnit < Record
    belongs_to :agency_group, class_name: 'Aim::AgencyGroup', inverse_of: :units

    before_validation do
      self.agency_id = agency_id.to_s.strip.upcase
      self.budget_unit = budget_unit.to_s.strip
    end

    validates :agency_id, :budget_unit, presence: true
    validates :budget_unit, uniqueness: { scope: :agency_id, message: 'is already in another custom group' }
    validate :same_agency_as_group

    private

    def same_agency_as_group
      return if agency_group.nil? || agency_group.agency_id == agency_id

      errors.add(:budget_unit, "belongs to #{agency_id}, not #{agency_group.agency_id}")
    end
  end
end
