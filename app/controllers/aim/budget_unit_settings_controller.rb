# frozen_string_literal: true

module Aim
  # A budget unit's settings (#131), from its agency group's BUs & People tab:
  # the high-dollar second approval, an amount and a second approver who works
  # AIM. AIM Admins, and the group's Group Admins. Both blank turns it off.
  class BudgetUnitSettingsController < BaseController
    before_action :set_group

    def update
      unit = params[:budget_unit].to_s
      return back(unit, alert: 'That budget unit is not in this group.') unless helpers.aim_agency_groups.units_of(@group).include?(unit)

      approver = params[:second_approver_employee_id].presence&.to_i
      return back(unit, alert: 'The second approver must work AIM.') if approver && !Aim::Users.member?(approver)

      setting = Aim::BudgetUnitSetting.find_or_initialize_by(agency_id: @group.agency_id, budget_unit: unit)
      setting.update!(second_approval_over: params[:second_approval_over].presence, second_approver_employee_id: approver,
                      updated_by: current_user_email)
      back(unit, notice: setting.second_approval? ? "#{unit}: second approval saved." : "#{unit}: no second approval.")
    rescue ActiveRecord::RecordInvalid => e
      back(unit, alert: e.record.errors.full_messages.to_sentence)
    end

    private

    def set_group
      @group = Aim::AgencyGroup.find_by(id: params[:agency_group_id])
      groups = helpers.aim_admin_groups
      return if @group && (groups.nil? || groups.any? { |g| g.id == @group.id })

      redirect_to aim_root_path, alert: 'Only AIM Admins and its Group Admins change a budget unit\'s settings.'
    end

    def back(unit, **flash)
      redirect_to aim_agency_group_path(@group, tab: 'bu_people', open: unit, anchor: "bu-#{unit}"), **flash
    end
  end
end
