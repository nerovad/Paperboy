# frozen_string_literal: true

module Aim
  # Switches an AIM Admin between Admin mode and Approver mode
  # for this session, and optionally makes the choice the mode they start in.
  class ModesController < BaseController
    def update
      return redirect_to(aim_root_path) unless helpers.aim_real_queue_access?

      mode = Aim::UserPreference::MODES.include?(params[:mode]) ? params[:mode] : 'admin'
      session[:aim_mode] = mode
      save_default(mode) if params[:default] == '1'
      redirect_to mode == 'approver' ? aim_my_queue_path : aim_root_path,
                  notice: "#{mode == 'approver' ? 'Approver' : 'Admin'} mode#{', and you will start in it' if params[:default] == '1'}."
    end

    private

    def save_default(mode)
      return if current_user_employee_id.nil?

      preference = Aim::UserPreference.find_or_initialize_by(employee_id: current_user_employee_id)
      preference.update!(start_mode: mode)
    end
  end
end
