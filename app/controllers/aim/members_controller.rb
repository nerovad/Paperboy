# frozen_string_literal: true

module Aim
  # Adding and removing the people who work AIM, and opening one person's
  # profile, from the Admin screen or the BU page. A person who still owns
  # invoices is not removed: their queue lists them with the Move tools, and
  # removal works once they are gone.
  #
  # AIM admins do all of it. A BU Admin adds people with a BU they administer
  # and opens the profiles of people in those BUs; deleting stays with AIM
  # admins (roles, 2026-09-25).
  class MembersController < BaseController
    include Aim::StageTabs

    before_action :require_aim_user_admin, only: :destroy
    before_action :require_people_manager, except: :destroy
    before_action :remember_queue_page, only: :show

    SEARCH_LIMIT = 20

    # Adds someone to AIM, and with `budget_unit` to that BU too. A BU Admin
    # must name one of their BUs; they come back to the BU page.
    def create
      unit = params[:budget_unit].to_s.strip.presence
      back = unit ? aim_budget_units_path : aim_admin_path
      return redirect_to(back, alert: 'You can only add people to your own budget units.') unless unit_manageable?(unit)

      employee = Employee.find_by(id: params[:employee_id].presence&.to_i)
      return redirect_to(back, alert: 'Pick a person from the search results.') if employee.nil?

      member = Aim::Member.find_or_initialize_by(employee_id: employee.id)
      already = member.persisted?
      member.update!(added_by: current_user_email) unless already
      grant_unit(employee, unit) if unit
      redirect_to back, notice: "#{employee.full_name} #{already ? 'already works' : 'now works'} AIM" \
                                "#{" in #{unit}" if unit}."
    end

    # A person's queue, as an admin sees it: the open invoices they own, with
    # the queue's Move tools, and Remove once there are none. Keyed by
    # employee id, so it opens for people who are AIM users through a group
    # as well as those on the Admin list.
    def show
      @employee_id = params[:id].to_i
      @employee = Employee.find_by(id: @employee_id)
      @member = Aim::Member.find_by(employee_id: @employee_id)
      # A list entry GSABSS no longer knows still opens, so a leaver's
      # invoices can be moved.
      return redirect_to(aim_admin_path, alert: 'That person does not work AIM.') unless @member || Aim::Users.member?(@employee_id)
      return redirect_to(aim_budget_units_path, alert: 'That person is not in your budget units.') unless in_my_units?

      @open_count = Aim::Member.open_invoices_of(@employee_id).count
      @invoices = invoices_for_tab(Aim::Invoice.where(assigned_employee_id: @employee_id))
      @home_unit = @employee&.unit.presence
      @budget_units = Aim::UserBudgetUnit.for_person(@employee_id).order(:budget_unit).to_a
      @units = Aim::Units.new
      @roles = Aim::Users.roles_of(@employee_id)
    end

    def destroy
      member = Aim::Member.find_by!(employee_id: params[:id].to_i)
      name = member.employee ? member.employee.full_name : "Employee #{member.employee_id}"
      if member.open_invoices.exists?
        return redirect_to(aim_member_path(member.employee_id),
                           alert: "#{name} still has invoices. Move them to another person or a shared queue first.")
      end

      # The second of two confirmations, checked here so it cannot be skipped:
      # the person's employee id, typed. The first is the page's pop-up.
      if params[:confirm_employee_id].to_s.strip != member.employee_id.to_s
        return redirect_to(aim_member_path(member.employee_id, anchor: 'delete'),
                           alert: "Type #{name}'s employee ID to confirm the delete.")
      end

      member.destroy!
      redirect_to aim_admin_path, notice: removed_notice(member, name)
    end

    # Every employee, for adding someone: the picker's search, not limited
    # to AIM users the way Aim::PeopleController is.
    def employees
      query = params[:q].to_s.strip
      return render json: [] if query.blank?

      render json: Employee.search_ranked(query).limit(SEARCH_LIMIT).search_options
    end

    private

    # AIM admins manage every BU; a BU Admin only theirs. No unit (the Admin
    # screen's plain add) is for AIM admins.
    def unit_manageable?(unit)
      units = helpers.aim_managed_units
      return units.nil? if unit.nil?

      units.nil? || units.include?(unit)
    end

    def in_my_units?
      units = helpers.aim_managed_units
      units.nil? || Aim::Users.budget_units_of(@employee_id).intersect?(units)
    end

    # Their home unit needs no row; any other BU does.
    def grant_unit(employee, unit)
      return if employee.unit.to_s == unit

      Aim::UserBudgetUnit.find_or_create_by!(employee_id: employee.id, budget_unit: unit) do |row|
        row.granted_by = current_user_email
      end
    end

    # Removing someone from the list does not end access they hold through a
    # group, during the switchover; say so.
    def removed_notice(member, name)
      notice = "#{name} was removed from AIM."
      return notice unless Aim::Users.group_employee_ids.include?(member.employee_id)

      "#{notice} They still work AIM through an AIM group; remove them from it under ACL to end that."
    end
  end
end
