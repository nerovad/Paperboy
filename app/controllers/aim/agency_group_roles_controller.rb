# frozen_string_literal: true

module Aim
  # Who is Fiscal or Group Admin in an agency group (#131). AIM Admins set
  # both; a Group Admin sets the group's Fiscal people only.
  class AgencyGroupRolesController < BaseController
    before_action :set_group

    def create
      role = params[:role].to_s
      return refuse unless allowed?(role)

      employee_id = params[:employee_id].to_i
      return back(alert: 'Pick someone.') unless Employee.exists?(id: employee_id)

      @group.roles.find_or_create_by!(employee_id: employee_id, role: role) { |r| r.granted_by = current_user_email }
      back(notice: "#{Aim::AgencyGroup::ROLES[role]} added.")
    rescue ActiveRecord::RecordInvalid => e
      back(alert: e.record.errors.full_messages.to_sentence)
    end

    def destroy
      row = @group.roles.find_by(id: params[:id])
      return back(alert: 'Already gone.') if row.nil?
      return refuse unless allowed?(row.role)

      row.destroy!
      back(notice: "#{row.label} taken away.")
    end

    private

    def set_group
      @group = Aim::AgencyGroup.find_by(id: params[:agency_group_id])
      groups = helpers.aim_admin_groups
      return if @group && (groups.nil? || groups.any? { |g| g.id == @group.id })

      redirect_to aim_root_path, alert: 'Only AIM Admins and its Group Admins change an agency group.'
    end

    def allowed?(role)
      return helpers.aim_user_admin? if role == 'admin'

      Aim::AgencyGroup::ROLES.key?(role)
    end

    def refuse = back(alert: 'Only AIM Admins make Group Admins.')

    def back(**flash) = redirect_to(aim_agency_group_path(@group, anchor: 'people'), **flash)
  end
end
