# frozen_string_literal: true

module Aim
  # A person's Group Admin and Fiscal roles in every agency group, ticked on
  # their profile (#131) as BU Admin is. AIM Admins (staff) only; a Group
  # Admin sets their own group's Fiscal people on the group's page.
  class MemberGroupRolesController < BaseController
    before_action :require_aim_user_admin

    def update
      employee_id = params[:id].to_i
      wanted = params.fetch(:roles, {}).to_unsafe_h.flat_map do |group_id, roles|
        Array(roles).map(&:to_s).select { |role| Aim::AgencyGroup::ROLES.key?(role) }.map { |role| [group_id.to_i, role] }
      end
      wanted &= Aim::AgencyGroup.pluck(:id).product(Aim::AgencyGroup::ROLES.keys)
      Aim::AgencyGroupRole.transaction do
        held = Aim::AgencyGroupRole.where(employee_id: employee_id).to_a
        held.reject { |row| wanted.include?([row.agency_group_id, row.role]) }.each(&:destroy!)
        (wanted - held.map { |row| [row.agency_group_id, row.role] }).each do |group_id, role|
          Aim::AgencyGroupRole.create!(agency_group_id: group_id, employee_id: employee_id, role: role, granted_by: current_user_email)
        end
      end
      redirect_to aim_member_path(employee_id, anchor: 'groups'), notice: 'Agency group roles saved.'
    end
  end
end
