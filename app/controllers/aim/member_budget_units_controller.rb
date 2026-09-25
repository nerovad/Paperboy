# frozen_string_literal: true

module Aim
  # A person's budget units, from their profile (item a.2): add a BU, take it
  # away, and make them BU Admin of it or not. Their home unit comes from
  # GSABSS; a row for it only carries the BU Admin flag, and goes when that is
  # cleared. AIM admins only for now; BU Admins get their own BUs next.
  class MemberBudgetUnitsController < BaseController
    before_action :require_aim_user_admin
    before_action :set_person

    def create
      unit = params[:budget_unit].to_s.strip
      return back(alert: 'Pick a budget unit.') if unit.blank?

      row = Aim::UserBudgetUnit.find_or_initialize_by(employee_id: @employee_id, budget_unit: unit)
      row.bu_admin = true if params[:bu_admin] == '1'
      row.granted_by = current_user_email
      row.save!
      back(notice: "#{unit} added#{' as BU Admin' if row.bu_admin}.")
    end

    def update
      row = Aim::UserBudgetUnit.for_person(@employee_id).find(params[:id])
      admin = params[:bu_admin] == '1'
      if !admin && row.budget_unit == home_unit
        row.destroy!
      else
        row.update!(bu_admin: admin, granted_by: current_user_email)
      end
      back(notice: "#{row.budget_unit}: #{admin ? 'now BU Admin' : 'no longer BU Admin'}.")
    end

    def destroy
      row = Aim::UserBudgetUnit.for_person(@employee_id).find(params[:id])
      row.destroy!
      back(notice: "#{row.budget_unit} taken away.")
    end

    private

    def set_person
      @employee_id = params[:member_id].to_i
      return if Aim::Member.exists?(employee_id: @employee_id) || Aim::Users.member?(@employee_id)

      redirect_to aim_admin_path, alert: 'That person does not work AIM.'
    end

    def home_unit = Employee.where(id: @employee_id).pick(:unit).presence

    def back(**flash_message)
      redirect_to aim_member_path(@employee_id, anchor: 'roles'), **flash_message
    end
  end
end
