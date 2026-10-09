# frozen_string_literal: true

class FormsController < ApplicationController
  # The landing page: where signed-out visitors find the Login button.
  skip_before_action :require_sign_in, only: :home

  # Paperboy's front door. Someone who starred Advanced Search starts in the
  # Form Library instead. /forms/home is this same page without that detour,
  # so the Quick Search button always has somewhere to land.
  def home
    return unless current_user && request.path == root_path
    return unless UserSetting.search_mode_for(current_user.employee_id) == 'advanced'

    flash.keep
    redirect_to form_library_path
  end
end
