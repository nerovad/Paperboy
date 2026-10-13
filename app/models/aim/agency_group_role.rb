# frozen_string_literal: true

module Aim
  # Someone's role in an agency group (#131). Fiscal works the group's Fiscal
  # stage and its coding rules; a Group Admin does that too and also sets the
  # group's Fiscal people and settings. AIM Admins hold every group already.
  class AgencyGroupRole < Record
    belongs_to :agency_group, class_name: 'Aim::AgencyGroup', inverse_of: :roles

    validates :employee_id, presence: true
    validates :role, inclusion: { in: Aim::AgencyGroup::ROLES.keys }
    validates :employee_id, uniqueness: { scope: %i[agency_group_id role] }

    def label = Aim::AgencyGroup::ROLES.fetch(role, role)
  end
end
