class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  helper_method :current_user

  def current_user
    user_data = session[:user]
    return nil unless user_data&.dig("employee_id") && user_data&.dig("email")

    @current_user ||= SessionUser.new(
      employee_id: user_data["employee_id"],
      email: user_data["email"],
      first_name: user_data["first_name"],
      last_name: user_data["last_name"]
    )
  end
end
