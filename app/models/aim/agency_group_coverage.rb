# frozen_string_literal: true

module Aim
  # "Fiscal also processes" (#131, Joshua 2026-10-13): agency_group's Fiscal
  # people and Group Admins also work covered_group's Fiscal stage and coding
  # rules. The covered group keeps its own people too.
  class AgencyGroupCoverage < Record
    belongs_to :agency_group, class_name: 'Aim::AgencyGroup', inverse_of: :coverages
    belongs_to :covered_group, class_name: 'Aim::AgencyGroup'

    validates :covered_group_id, uniqueness: { scope: :agency_group_id }
    validate :not_itself

    private

    def not_itself
      errors.add(:covered_group_id, 'is this group itself') if covered_group_id == agency_group_id
    end
  end
end
