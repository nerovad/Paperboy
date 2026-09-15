# frozen_string_literal: true

# app/models/scheduled_report.rb
class ScheduledReport < ApplicationRecord
  include RecurringSchedule

  DATE_RANGE_TYPES = {
    'last_7_days' => 'Last 7 days',
    'last_30_days' => 'Last 30 days',
    'last_month' => 'Last month (calendar)',
    'last_week' => 'Last week (calendar)',
    'yesterday' => 'Yesterday',
    'today' => 'Today'
  }.freeze

  FORMATS = {
    'csv' => 'CSV',
    'pdf' => 'PDF'
  }.freeze

  # Validations (the schedule's own live in RecurringSchedule)
  validates :form_type, presence: true
  validates :format, presence: true, inclusion: { in: FORMATS.keys }
  validates :date_range_type, presence: true, inclusion: { in: DATE_RANGE_TYPES.keys }

  def form_template
    Forms::Template.all.find { |t| t.class_name.tableize == form_type }
  end

  def form_name
    form_template&.name || form_type.humanize
  end

  # Date range calculation
  def calculate_date_range
    case date_range_type
    when 'last_7_days'
      [7.days.ago.to_date, Date.yesterday]
    when 'last_30_days'
      [30.days.ago.to_date, Date.yesterday]
    when 'last_month'
      last_month = Date.current.last_month
      [last_month.beginning_of_month, last_month.end_of_month]
    when 'last_week'
      last_week = Date.current.last_week
      [last_week.beginning_of_week, last_week.end_of_week]
    when 'yesterday'
      [Date.yesterday, Date.yesterday]
    when 'today'
      [Date.today, Date.today]
    else
      [7.days.ago.to_date, Date.yesterday]
    end
  end

  # Execute the report
  def execute!
    start_date, end_date = calculate_date_range

    ReportGenerationJob.perform_later(
      employee_id,
      form_type,
      start_date.to_s,
      end_date.to_s,
      format,
      status_filter.presence
    )

    update(last_run_at: Time.current)
    update_next_run!
  end

  # Display helpers
  def date_range_label
    DATE_RANGE_TYPES[date_range_type]
  end

  def format_label
    FORMATS[format]
  end

  def schedule_description
    "#{timing_description} (#{date_range_label})"
  end
end
