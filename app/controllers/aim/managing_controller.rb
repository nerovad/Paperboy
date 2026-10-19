# frozen_string_literal: true

module Aim
  # "Managing" (#131): which agency group the Fiscal and Lookups pages show,
  # for someone who works more than one. Kept in the session; blank is all of
  # theirs. Only a group they work can be picked.
  class ManagingController < BaseController
    before_action :require_fiscal

    def update
      id = params[:agency_group_id].presence
      groups = helpers.aim_fiscal_groups
      if id && (groups.nil? ? !Aim::AgencyGroup.exists?(id: id) : groups.none? { |group| group.id == id.to_i })
        return redirect_to(back, alert: 'That agency group is not one of yours.')
      end

      session[:aim_agency_group_id] = id&.to_i
      redirect_to back
    end

    private

    def back
      path = params[:return_to].to_s
      path.start_with?('/aim/') && !path.start_with?('//') ? path : aim_fiscal_path
    end
  end
end
