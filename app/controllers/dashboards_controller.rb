class DashboardsController < ApplicationController
  before_action :require_authentication

  def index
    @dashboard_forms = FormTemplate.with_dashboards.order(:name)

    @selected_form = if params[:form_id].present?
      FormTemplate.find_by(id: params[:form_id])
    else
      @dashboard_forms.first
    end

    if @selected_form&.has_dashboard?
      @embed_url = MetabaseService.new.embed_url(@selected_form.metabase_dashboard_id)
    end
  end

  private

  def require_authentication
    unless session[:user_id]
      redirect_to root_path, alert: "Please log in to access dashboards"
    end
  end
end
