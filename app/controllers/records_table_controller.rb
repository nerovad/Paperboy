# frozen_string_literal: true

# Generic grid for a Records table (see Registry) that has no bespoke screen of
# its own. Renders the customizable, sortable column table shared with
# Inbox/Submissions. Tables that declare a `route:` (e.g. P-Cards) are bounced
# to their own richer screen instead.
class RecordsTableController < ApplicationController
  include Filterable

  before_action :set_table

  def show
    @page = @table.page_key
    @layout = UserSetting.for_employee(current_employee_id).layout_for(@page)
    @columns = TableColumns.resolve(@page, @layout)

    rows = @table.scope.to_a
    @default_sort = default_sort_key(@columns)
    sort_by = params[:sort_by].presence || @default_sort
    sort_direction = params[:sort_direction] || 'asc'
    sort_configs = @columns.select(&:sortable?).index_by(&:sort_key).transform_values(&:value)

    @records = sort_collection(rows, sort_by, sort_direction, sort_configs, default_sort: @default_sort)
  end

  private

  def set_table
    @table = RegistryTable.find(params[:slug])
    return redirect_to(records_path, alert: 'Unknown table.') unless @table
    return redirect_to(root_path, alert: 'Access denied.') unless helpers.can_access_record_table?(@table)

    # A table with its own screen is served there, not by the generic grid.
    redirect_to(public_send(@table.route)) if @table.route.present?
  end

  def current_employee_id
    session.dig(:user, 'employee_id')
  end
end
