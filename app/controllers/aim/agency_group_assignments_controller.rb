# frozen_string_literal: true

module Aim
  # Adds someone to one of an agency group's budget units, from the group's
  # BUs & People tab (#131): onto the AIM list if they are not on it, the BU
  # granted, its shared queue on if asked, BU Admin if asked and allowed. AIM
  # Admins, and Group Admins and BU Admins for the units they manage.
  class AgencyGroupAssignmentsController < BaseController
    before_action :require_people_manager

    def create
      group = Aim::AgencyGroup.find(params[:id])
      unit = params[:budget_unit].to_s
      employee = Employee.find_by(id: params[:employee_id].presence&.to_i)
      back = aim_agency_group_path(group, tab: 'bu_people', open: unit, anchor: "bu-#{unit}")
      return redirect_to(back, alert: 'Pick a person.') if employee.nil?
      return redirect_to(back, alert: 'You do not manage that budget unit.') unless assignable?(group, unit)

      Aim::Member.find_or_create_by!(employee_id: employee.id) { |m| m.added_by = current_user_email }
      grant(employee, unit)
      redirect_to back, notice: "#{employee.full_name} now works #{unit}."
    end

    private

    def assignable?(group, unit)
      managed = helpers.aim_managed_units
      helpers.aim_agency_groups.units_of(group).include?(unit) && (managed.nil? || managed.include?(unit))
    end

    # The home unit needs a row only to carry a flag.
    def grant(employee, unit)
      row = Aim::UserBudgetUnit.find_or_initialize_by(employee_id: employee.id, budget_unit: unit)
      row.hidden = false
      row.shared_queue = true if params[:shared_queue] == '1'
      row.bu_admin = true if params[:bu_admin] == '1' && helpers.aim_appoints_bu_admin?(unit)
      return if row.new_record? && Aim::Users.home_unit(employee) == unit && !row.shared_queue && !row.bu_admin

      row.granted_by = current_user_email
      row.save!
    end
  end
end
