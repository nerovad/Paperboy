class SettingsController < ApplicationController
  def show
    @settings = current_user_settings
  end

  def update
    @settings = current_user_settings
    if @settings.update(settings_params)
      redirect_to settings_path, notice: "Settings saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def current_user_settings
    employee_id = session.dig(:user, "employee_id")
    UserSetting.find_or_initialize_by(employee_id: employee_id)
  end

  def settings_params
    params.require(:user_setting).permit(:inbox_email_notifications)
  end
end
