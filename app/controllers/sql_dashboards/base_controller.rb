# frozen_string_literal: true

module SqlDashboards
  # Two grants, deliberately separate. Looking at a dashboard is
  # `sql_dashboards`. Writing SQL and building dashboards is
  # `sql_dashboard_queries`, which also lets its holder look.
  class BaseController < ApplicationController
    private

    def require_viewer
      return if helpers.sql_dashboards_viewer?

      redirect_to root_path, alert: 'Access denied.'
    end

    def require_author
      return if helpers.sql_dashboards_author?

      redirect_to helpers.sql_dashboards_viewer? ? sql_dashboards_dashboards_path : root_path,
                  alert: 'Access denied.'
    end

    def actor_stamp(prefix)
      { "#{prefix}_by_id": current_user.employee_id.to_s,
        "#{prefix}_by_name": "#{current_user.first_name} #{current_user.last_name}".strip }
    end
  end
end
