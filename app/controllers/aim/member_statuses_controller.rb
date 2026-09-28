# frozen_string_literal: true

module Aim
  # Deactivating someone who left, and bringing them back (item a.2). An
  # inactive person drops out of the picker and the queues, but their record,
  # BUs and history stay. Their open invoices are moved first, as for a delete.
  # An AIM Admin does this for anyone; a BU Admin only for someone whose BUs
  # are all theirs.
  class MemberStatusesController < BaseController
    before_action :require_people_manager
    before_action :set_member

    def deactivate
      if @member.open_invoices.exists?
        return redirect_to(aim_member_path(@employee_id),
                           alert: 'Move their open invoices to another person or a shared queue first.')
      end

      @member.deactivate!(by: current_user_email, reason: params[:reason])
      redirect_to aim_member_path(@employee_id), notice: 'Deactivated. Reactivate them here if they come back.'
    end

    def reactivate
      @member.reactivate!
      redirect_to aim_member_path(@employee_id), notice: 'Reactivated.'
    end

    private

    def set_member
      @member = Aim::Member.find_by!(employee_id: params[:id].to_i)
      @employee_id = @member.employee_id
      return if helpers.aim_manages_all_units_of?(@employee_id)

      redirect_to aim_member_path(@employee_id), alert: 'They also work in BUs you do not manage. Ask an AIM Admin.'
    end
  end
end
