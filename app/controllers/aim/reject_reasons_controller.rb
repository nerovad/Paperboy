# frozen_string_literal: true

module Aim
  # The reject reasons every agency group is offered (#131), kept by AIM
  # Admins on Agency Groups. A group's own are on its Fiscal settings tab.
  class RejectReasonsController < BaseController
    before_action :require_aim_user_admin

    def update
      Aim::RejectReason.replace!(nil, params[:reject_reasons], by: current_user_email)
      redirect_to aim_agency_groups_path, notice: 'Reject reasons saved.'
    end
  end
end
