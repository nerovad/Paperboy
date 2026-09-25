# frozen_string_literal: true

module Aim
  # A person's budget units, from their profile (item a.2): add a BU, take it
  # away, and make them BU Admin of it or not. Their home unit comes from
  # GSABSS; a row for it only carries the BU Admin flag, and goes when that is
  # cleared. AIM admins do all of it; a BU Admin adds and takes away only the
  # BUs they administer, and appoints no BU Admins and hides nothing.
  class MemberBudgetUnitsController < BaseController
    before_action :require_people_manager
    before_action :require_aim_user_admin, only: :update
    before_action :set_person

    def create
      unit = params[:budget_unit].to_s.strip
      return back(alert: 'Pick a budget unit.') if unit.blank?
      return back(alert: 'You can only add your own budget units.') unless manageable?(unit)

      row = Aim::UserBudgetUnit.find_or_initialize_by(employee_id: @employee_id, budget_unit: unit)
      row.bu_admin = true if params[:bu_admin] == '1' && full_admin?
      row.hidden = true if params[:hidden] == '1' && unit == home_unit && full_admin?
      row.granted_by = current_user_email
      row.save!
      back(notice: "#{unit}: #{describe(row)}.")
    end

    # BU Admin on or off, or (home unit only) hidden or shown. Hiding clears
    # BU Admin: they see nothing there. A home unit row with neither goes.
    def update
      row = Aim::UserBudgetUnit.for_person(@employee_id).find(params[:id])
      if params.key?(:hidden)
        hidden = params[:hidden] == '1' && row.budget_unit == home_unit
        row.assign_attributes(hidden: hidden, bu_admin: hidden ? false : row.bu_admin)
      else
        row.bu_admin = params[:bu_admin] == '1'
      end
      settle(row)
      back(notice: "#{row.budget_unit}: #{describe(row)}.")
    end

    def destroy
      row = Aim::UserBudgetUnit.for_person(@employee_id).find(params[:id])
      return back(alert: "You cannot take #{row.budget_unit} away from this person.") unless removable?(row)

      row.destroy!
      back(notice: "#{row.budget_unit} taken away.")
    end

    private

    def set_person
      @employee_id = params[:member_id].to_i
      return if Aim::Member.exists?(employee_id: @employee_id) || Aim::Users.member?(@employee_id)

      redirect_to aim_admin_path, alert: 'That person does not work AIM.'
    end

    def full_admin? = helpers.aim_managed_units.nil?

    # A BU Admin takes away their own BUs, but not from another BU Admin of it.
    def removable?(row) = full_admin? || (manageable?(row.budget_unit) && !row.bu_admin)

    def manageable?(unit)
      units = helpers.aim_managed_units
      units.nil? || units.include?(unit)
    end

    def home_unit = Employee.where(id: @employee_id).pick(:unit).presence

    # A home unit row that is neither BU Admin nor hidden says nothing.
    def settle(row)
      if row.budget_unit == home_unit && !row.bu_admin && !row.hidden
        row.destroy!
      else
        row.update!(granted_by: current_user_email)
      end
    end

    def describe(row)
      return 'hidden' if row.hidden

      row.bu_admin ? 'BU Admin' : 'User'
    end

    def back(**flash_message)
      redirect_to aim_member_path(@employee_id, anchor: 'roles'), **flash_message
    end
  end
end
