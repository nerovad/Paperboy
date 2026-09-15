# frozen_string_literal: true

# A Records grid view emailed to its owner as a CSV on a schedule — "the fleet
# vehicles in agency 12, with my columns, every Monday at 07:00".
#
# The view is a snapshot taken when the schedule is created: the search,
# column filters and sort from the grid's query string (view_params) and the
# owner's column layout at that moment (layout). Each run rebuilds a
# RecordsView from the snapshot against live rows, so the email carries the
# table as it stands on the day it is sent. Changing the grid afterwards does
# not change the schedule; delete it and schedule the new view instead.
#
# Access is re-checked on every run (see RecordExportJob), not only at creation.
class ScheduledRecordExport < ApplicationRecord
  include RecurringSchedule

  serialize :view_params, coder: JSON
  serialize :layout, coder: JSON

  # Grid query keys a snapshot keeps. Anything else in the query string (page
  # chrome, Turbo params) has no bearing on which rows or columns are shown.
  VIEW_KEYS = %w[search sort_by sort_direction].freeze
  FILTER_KEY = /\Afilter_[a-z0-9_]+\z/

  validates :table_slug, presence: true
  validate :table_must_exist

  before_create :schedule_first_run

  # The grid query keys worth keeping from a request's query string, with
  # blank values dropped. Filter values stay strings or arrays of strings, the
  # two shapes Filterable#apply_filters accepts.
  def self.view_params_from(query)
    return {} unless query.is_a?(Hash)

    query.each_with_object({}) do |(key, value), kept|
      key = key.to_s
      next unless VIEW_KEYS.include?(key) || key.match?(FILTER_KEY)
      next if value.is_a?(Hash)

      value = value.is_a?(Array) ? value.map(&:to_s).compact_blank : value.to_s.strip
      kept[key] = value if value.present?
    end
  end

  def table
    return @table if defined?(@table)

    @table = RegistryTable.find(table_slug)
  end

  def table_label
    table&.label || table_slug
  end

  # Rebuild the saved view against today's rows.
  def build_view
    RecordsView.new(table, layout: columns_layout, params: (view_params || {}).with_indifferent_access)
  end

  # The saved layout, cleaned against the table's current columns. A column
  # dropped from the table since is ignored; a snapshot left with nothing falls
  # back to the table's default columns rather than sending an empty file.
  def columns_layout
    cleaned = TableColumns.sanitize_layout(table.page_key, layout)
    cleaned.presence || TableColumns.default_layout(table.page_key)
  end

  def execute!
    RecordExportJob.perform_later(id)

    update(last_run_at: Time.current)
    update_next_run!
  end

  # "Search "ford" · Make: Ford" -- how a view narrows its table, labelled
  # with the table's own column names.
  def self.describe_view(table, view_params)
    params = view_params || {}
    parts = []
    parts << %(Search "#{params['search']}") if params['search'].present?

    params.each do |key, value|
      next unless key.to_s.match?(FILTER_KEY)

      name = key.to_s.delete_prefix('filter_')
      label = table&.columns&.find { |column| column.name.to_s == name }&.label || name.humanize
      parts << "#{label}: #{Array(value).join(', ')}"
    end

    parts.any? ? parts.join(' · ') : 'All rows'
  end

  def view_description
    self.class.describe_view(table, view_params)
  end

  def schedule_description
    timing_description
  end

  private

  def table_must_exist
    return if table_slug.blank?
    return errors.add(:table_slug, 'is not a Records table') unless table

    # A table with its own screen (P-Cards) does not use the generic grid, so
    # there is no grid view to snapshot.
    errors.add(:table_slug, 'has its own export') if table.route.present?
  end

  def schedule_first_run
    self.next_run_at ||= calculate_next_run
  end
end
