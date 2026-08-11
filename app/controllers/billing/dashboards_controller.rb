# frozen_string_literal: true

module Billing
  # Embeds the selected Billing dashboard from Metabase.
  class DashboardsController < BaseController
    before_action -> { require_app_feature('billing', 'view_billing', fallback: billing_root_path) }

    def show
      @dashboards = Dashboard.all
      @selected_dashboard = selected_dashboard
      build_embed_url
    end

    private

    def selected_dashboard
      @dashboards.find { |dashboard| dashboard.key == params[:dashboard] } || @dashboards.first
    end

    def build_embed_url
      unless @selected_dashboard.configured?
        @configuration_error = "#{@selected_dashboard.environment_key} is not configured."
        return
      end

      @embed_url = MetabaseService.new.embed_url(@selected_dashboard.dashboard_id)
    rescue KeyError => e
      @configuration_error = "#{e.key} is not configured."
    end
  end
end
