# frozen_string_literal: true

module Aim
  # How AIM works (#131): one page, by task, with screenshots from
  # app/assets/images/aim/help/ where there is one -- for AIM staff, Fiscal
  # and admins (aim_full_help?). Everyone else, who only approves, gets the
  # short How to approve; ?for=approver shows it to staff too.
  class HelpController < BaseController
    def show
      render :approver if params[:for] == 'approver' || !helpers.aim_full_help?
    end
  end
end
