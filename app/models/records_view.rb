# frozen_string_literal: true

# One view of a Records table: the columns someone chose, narrowed by their
# search and column filters and put in their sort order. The grid renders it,
# its CSV download writes it, and a ScheduledRecordExport rebuilds it from a
# saved snapshot on every run, so all three agree on which rows are "the rows
# on screen".
#
# `params` is anything that answers `[]` with the grid's query keys (search,
# filter_*, sort_by, sort_direction): the request's params, or a schedule's
# stored hash.
class RecordsView
  include Filterable

  attr_reader :table, :columns, :filter_options, :default_sort, :rows

  def initialize(table, layout:, params:)
    @table = table
    @params = params
    # Narrowing the grid to one agency lets the org headers use that agency's
    # own vocabulary; unfiltered, they stay canonical.
    @columns = TableColumns.resolve(table.page_key, layout, context: { org_agency: params[:filter_agency] })
    build
  end

  private

  attr_reader :params

  def build
    rows = RecordsSearch.apply(table, table.scope.to_a, params[:search])

    # Dropdown values come from the searched set but before the column filters
    # narrow it, so picking one value doesn't empty every other dropdown.
    @filter_options = collect_filter_options(rows, select_filter_extractors)
    rows = apply_column_filters(rows)

    @default_sort = default_sort_key(columns)
    sort_by = params[:sort_by].presence || default_sort
    sort_direction = params[:sort_direction] || 'asc'
    sort_configs = columns.select(&:sortable?).index_by(&:sort_key).transform_values(&:value)

    @rows = sort_collection(rows, sort_by, sort_direction, sort_configs, default_sort: default_sort)
  end

  # Extractors for the columns that filter as a dropdown, keyed by filter param.
  def select_filter_extractors
    columns.select { |column| column.filterable? && !column.search_filter? }
           .to_h { |column| [column.filter_param.to_s, column.value] }
  end

  # `:select` columns match their dropdown value exactly; `:search` columns
  # match as a contains, which is what a free-text box implies. Filterable's
  # shared #apply_filters only matches exactly, so the contains pass lives here
  # rather than changing behaviour the Inbox and Submissions rely on.
  def apply_column_filters(rows)
    search_columns, select_columns = columns.select(&:filterable?).partition(&:search_filter?)

    rows = apply_filters(rows, filter_configs: select_columns.map do |column|
      { param: column.filter_param, extractor: column.value }
    end)

    search_columns.each do |column|
      needle = params[column.filter_param].to_s.strip.downcase
      next if needle.blank?

      rows = rows.select { |row| column.value.call(row).to_s.downcase.include?(needle) }
    end

    rows
  end
end
