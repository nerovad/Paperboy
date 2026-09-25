# frozen_string_literal: true

module Aim
  # Adding and removing the people who work AIM, and opening one person's
  # queue, from the Admin screen. A person who still owns invoices is not
  # removed: their queue lists them with the Move tools, and removal works
  # once they are gone.
  class MembersController < BaseController
    before_action :require_aim_user_admin
    before_action :remember_queue_page, only: :show

    SEARCH_LIMIT = 20

    def create
      employee = Employee.find_by(id: params[:employee_id].presence&.to_i)
      return redirect_to(aim_admin_path, alert: 'Pick a person from the search results.') if employee.nil?

      member = Aim::Member.find_or_initialize_by(employee_id: employee.id)
      if member.persisted?
        redirect_to aim_admin_path, notice: "#{display_name(employee)} already works AIM."
      else
        member.update!(added_by: current_user_email)
        redirect_to aim_admin_path, notice: "#{display_name(employee)} now works AIM."
      end
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

      @open_count = Aim::Member.open_invoices_of(@employee_id).count
      load_invoices
      @home_unit = @employee&.unit.presence
      @budget_units = Aim::UserBudgetUnit.for_person(@employee_id).order(:budget_unit).to_a
      @unit_options = Aim::UserBudgetUnit.unit_options
      @roles = Aim::Users.roles_of(@employee_id)
    end

    def destroy
      member = Aim::Member.find_by!(employee_id: params[:id].to_i)
      name = member.employee ? display_name(member.employee) : "Employee #{member.employee_id}"
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

    # The pipeline stages a person's invoices can be in besides their queue.
    PIPELINE_STAGES = (Aim::Invoice::QUEUES.keys - ['ready_for_approval']).freeze
    FINISHED_STAGES = %w[exported rejected deleted].freeze

    # Every employee, for adding someone: the picker's search, not limited
    # to AIM users the way Aim::PeopleController is.
    def employees
      query = params[:q].to_s.strip
      return render json: [] if query.blank?

      matches = matching(query).order(:last_name, :first_name).limit(SEARCH_LIMIT)
                               .pluck(:id, :first_name, :last_name, :unit)
      render json: matches.map { |id, first, last, unit|
        { value: id, label: "#{last}, #{first} (#{id})", unit: unit }
      }
    end

    private

    # Their queue (Ready for Approval) and everything else they own across the
    # pipeline, filtered by stage. Finished, rejected and deleted invoices are
    # left out unless asked for.
    def load_invoices
      owned = Aim::Invoice.where(assigned_employee_id: @employee_id)
      @tab = params[:tab] == 'pipeline' ? 'pipeline' : 'queue'
      @stages = Array(params[:stages]).presence&.intersection(PIPELINE_STAGES) || (PIPELINE_STAGES - FINISHED_STAGES)
      by_state = owned.group(:state).count
      @stage_counts = Aim::Invoice::QUEUES.transform_values { |queue| queue[:states].sum { |state| by_state.fetch(state, 0) } }
      states = @tab == 'queue' ? %w[ready_for_approval] : @stages.flat_map { |stage| Aim::Invoice::QUEUES[stage][:states] }
      @invoices = owned.where(state: states).newest_first.to_a
    end

    def matching(query)
      return Employee.where(id: query) if query.match?(/\A\d+\z/)

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      Employee.where('first_name LIKE :query OR last_name LIKE :query', query: pattern)
    end

    # Removing someone from the list does not end access they hold through a
    # group, during the switchover; say so.
    def removed_notice(member, name)
      notice = "#{name} was removed from AIM."
      return notice unless Aim::Users.group_employee_ids.include?(member.employee_id)

      "#{notice} They still work AIM through an AIM group; remove them from it under ACL to end that."
    end

    def display_name(employee) = "#{employee.first_name} #{employee.last_name}".squish
  end
end
