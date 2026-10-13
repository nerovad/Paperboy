# frozen_string_literal: true

# Dashboards built inside Paperboy from SQL an admin types in the browser.
#
# A Query is saved SQL plus the chart it draws. A Dashboard shows queries as
# Cards. Every run and every change to a query is an Event.
#
# Typed SQL is never inspected. What it can do is decided by the login it
# runs under (SqlDashboards::Database), a timeout and a row cap.
module SqlDashboards
  VIEW_FEATURE = 'sql_dashboards'
  AUTHOR_FEATURE = 'sql_dashboard_queries'
end
