class DashboardsController < ApplicationController
  before_action :require_authentication

  def index
    # Get all forms that have dashboards configured
    @dashboard_forms = FormTemplate.with_dashboards.order(:name)

    # Pre-select first form if available
    @selected_form = if params[:form_id].present?
      FormTemplate.find_by(id: params[:form_id])
    else
      @dashboard_forms.first
    end

    # Get embed configuration if form is selected
    if @selected_form&.has_dashboard?
      @embed_config = get_embed_config(@selected_form)
    end
  end

  def embed_token
    # AJAX endpoint for refreshing embed token
    form = FormTemplate.find(params[:form_id])

    if form&.has_dashboard?
      embed_config = get_embed_config(form)
      render json: embed_config
    else
      render json: { error: 'Dashboard not configured' }, status: :not_found
    end
  end

  private

  def require_authentication
    unless session[:user_id]
      redirect_to root_path, alert: "Please log in to access dashboards"
    end
  end

  def get_embed_config(form_template)
    service = PowerBiService.new(session)

    begin
      token_data = service.generate_embed_token(
        form_template.powerbi_workspace_id,
        form_template.powerbi_report_id
      )

      {
        type: 'report',
        id: form_template.powerbi_report_id,
        embedUrl: powerbi_embed_url(form_template),
        accessToken: token_data[:token],
        tokenExpiration: token_data[:expiration].iso8601,
        settings: {
          filterPaneEnabled: false,
          navContentPaneEnabled: true,
          background: 'transparent'
        }
      }
    rescue PowerBiService::PowerBiError => e
      Rails.logger.error("Failed to get Power BI embed config: #{e.message}")
      # Return error state that frontend can handle
      {
        error: true,
        message: "Unable to load dashboard: #{e.message}"
      }
    end
  end

  def powerbi_embed_url(form_template)
    base_url = ENV['POWERBI_EMBED_URL'] || 'https://app.powerbigov.us'
    "#{base_url}/reportEmbed?" \
    "reportId=#{form_template.powerbi_report_id}&" \
    "groupId=#{form_template.powerbi_workspace_id}"
  end
end
