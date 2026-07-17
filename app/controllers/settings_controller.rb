# frozen_string_literal: true

class SettingsController < ApplicationController
  def show
    @settings = current_user_settings
  end

  def update
    @settings = current_user_settings
    if @settings.update(settings_params)
      redirect_to settings_path, notice: 'Settings saved.'
    else
      render :show, status: :unprocessable_entity
    end
  end

  # Persist a customized column/filter layout for one page (:inbox or
  # :submissions). Called by the column-customizer Stimulus controller; the page
  # reloads afterwards so the server re-renders columns + filters.
  def table_layout
    page = params[:page].to_s
    return head :bad_request unless TableColumns.valid_page?(page)

    fields = table_layout_fields
    if current_user_settings.set_layout(page, fields)
      head :no_content
    else
      head :unprocessable_entity
    end
  end

  private

  # Normalize the incoming ordered field list into plain strings / hashes for
  # TableColumns.sanitize_layout. Each entry is either a built-in key string or
  # a custom descriptor { type:"field", form:, field:, label: }.
  def table_layout_fields
    Array(params[:fields]).map do |entry|
      if entry.respond_to?(:permit)
        entry.permit(:type, :form, :field, :label).to_h
      else
        entry.to_s
      end
    end
  end

  def current_user_settings
    employee_id = session.dig(:user, 'employee_id')
    UserSetting.find_or_initialize_by(employee_id: employee_id)
  end

  def settings_params
    params.require(:user_setting).permit(:inbox_email_notifications)
  end
end
