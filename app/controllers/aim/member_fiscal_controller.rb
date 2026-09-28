# frozen_string_literal: true

module Aim
  # The Fiscal switch on a profile (item f): who works the Fiscal queue. AIM
  # Admins set it, as they do every role that lives in AIM's own settings.
  class MemberFiscalController < BaseController
    before_action :require_aim_user_admin

    def update
      member = Aim::Member.find_by(employee_id: params[:id].to_i)
      return redirect_to(aim_admin_path, alert: 'Add them to AIM first.') if member.nil?

      on = params[:fiscal] == '1'
      member.update!(fiscal: on)
      redirect_to aim_member_path(member.employee_id), notice: on ? 'They now work the Fiscal queue.' : 'Fiscal taken away.'
    end
  end
end
