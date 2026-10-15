# frozen_string_literal: true

module Aim
  # An agency group's email alert settings (#131), or one of its budget
  # units' overrides, from the group's Alerts tab. AIM Admins and the group's
  # Group Admins. "Use the group's" drops a unit's override.
  class AgencyGroupAlertsController < BaseController
    before_action :set_group

    def update
      unit = params[:budget_unit].presence
      return back(alert: 'That budget unit is not in this group.') if unit && !helpers.aim_agency_groups.units_of(@group).include?(unit)

      if unit && params[:use_group] == '1'
        Aim::AlertSetting.where(agency_group_id: @group.id, budget_unit: unit).delete_all
        return back(unit, notice: "#{unit} follows the group's alerts.")
      end

      Aim::AlertSetting.replace!(@group, unit, submitted, by: current_user_email)
      back(unit, notice: unit ? "#{unit}'s alerts saved." : 'Alerts saved.')
    rescue ActiveRecord::RecordInvalid => e
      back(unit, alert: e.record.errors.full_messages.to_sentence)
    end

    private

    def set_group
      @group = Aim::AgencyGroup.find_by(id: params[:id])
      groups = helpers.aim_admin_groups
      return if @group && (groups.nil? || groups.any? { |g| g.id == @group.id })

      redirect_to aim_root_path, alert: 'Only AIM Admins and its Group Admins change its alerts.'
    end

    # { kind => { on:, days: } } from on[kind] and days[kind].
    def submitted
      on = params.fetch(:on, {}).permit(*Aim::AlertSetting::KINDS.keys).to_h
      days = params.fetch(:days, {}).permit(*Aim::AlertSetting::KINDS.keys).to_h
      Aim::AlertSetting::KINDS.to_h do |kind, default|
        [kind, { on: on[kind] == '1', days: days[kind].presence&.to_i || default[:days] }]
      end
    end

    def back(unit = nil, **flash)
      redirect_to aim_agency_group_path(@group, tab: 'alerts', open: unit, anchor: unit ? "alerts-#{unit}" : 'alerts'), **flash
    end
  end
end
