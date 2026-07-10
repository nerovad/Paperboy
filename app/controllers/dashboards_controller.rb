# frozen_string_literal: true

class DashboardsController < ApplicationController
  before_action :require_dashboards_access

  def index
    @dashboard_forms = FormTemplate.with_dashboards.order(:name)

    unless current_user_group_names.include?('system_admins')
      perm_keys = current_user_form_permission_keys
      @dashboard_forms = @dashboard_forms.select { |f| perm_keys.include?(f.id.to_s) }
    end

    @selected_form = if params[:form_id].present?
                       @dashboard_forms.find { |f| f.id == params[:form_id].to_i }
                     else
                       @dashboard_forms.first
                     end

    return unless @selected_form&.dashboard?

    @embed_url = MetabaseService.new.embed_url(@selected_form.metabase_dashboard_id)
  end

  private

  def require_dashboards_access
    unless session[:user_id]
      redirect_to root_path, alert: 'Please log in to access dashboards'
      return
    end

    return if current_user_group_names.include?('system_admins') || current_user_dropdown_permissions.include?('dashboards')

    redirect_to root_path, alert: 'Access denied.'
  end
end
