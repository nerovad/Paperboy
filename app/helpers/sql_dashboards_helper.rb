# frozen_string_literal: true

# Who may reach SQL Dashboards, and how a result value is written in a table.
module SqlDashboardsHelper
  def sql_dashboards_author?
    can_use_app_feature?('paperboy', SqlDashboards::AUTHOR_FEATURE)
  end

  def sql_dashboards_viewer?
    sql_dashboards_author? || can_use_app_feature?('paperboy', SqlDashboards::VIEW_FEATURE)
  end

  def sql_dashboard_cell(value)
    case value
    when nil then tag.span('NULL', class: 'sql-result__null')
    when Time, DateTime then value.strftime('%Y-%m-%d %H:%M:%S')
    when BigDecimal then value.to_s('F')
    when String then value.encoding == Encoding::BINARY ? "0x#{value.first(16).unpack1('H*')}" : value
    else value.to_s
    end
  end
end
