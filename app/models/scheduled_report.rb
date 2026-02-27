# app/models/scheduled_report.rb
class ScheduledReport < ApplicationRecord
  FREQUENCIES = {
    'daily' => 'Every day',
    'weekly' => 'Weekly',
    'monthly' => 'Monthly'
  }
  
  DATE_RANGE_TYPES = {
    'last_7_days' => 'Last 7 days',
    'last_30_days' => 'Last 30 days',
    'last_month' => 'Last month (calendar)',
    'last_week' => 'Last week (calendar)',
    'yesterday' => 'Yesterday',
    'today' => 'Today'
  }
  
  FORMATS = {
    'csv' => 'CSV',
    'pdf' => 'PDF'
  }
  
  # Validations
  validates :employee_id, presence: true
  validates :form_type, presence: true
  validates :format, presence: true, inclusion: { in: FORMATS.keys }
  validates :frequency, presence: true, inclusion: { in: FREQUENCIES.keys }
  validates :time_of_day, presence: true, format: { with: /\A\d{2}:\d{2}\z/, message: "must be in HH:MM format" }
  validates :date_range_type, presence: true, inclusion: { in: DATE_RANGE_TYPES.keys }
  
  validates :day_of_week, inclusion: { in: 0..6 }, if: -> { frequency == 'weekly' }
  validates :day_of_month, inclusion: { in: 1..31 }, if: -> { frequency == 'monthly' }
  
  # Scopes
  scope :enabled, -> { where(enabled: true) }
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }
  scope :due, -> { enabled.where('next_run_at <= ?', Time.current) }
  
  # Associations
  def employee
    Employee.find_by(employee_id: employee_id)
  end
  
  def form_template
    FormTemplate.all.find { |t| t.class_name.tableize == form_type }
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
  
  # Schedule calculation
  def calculate_next_run
    base_time = Time.current.in_time_zone('Pacific Time (US & Canada)')
    hour, minute = time_of_day.split(':').map(&:to_i)
    
    next_run = case frequency
    when 'daily'
      base_time.change(hour: hour, min: minute, sec: 0)
    when 'weekly'
      # Find next occurrence of day_of_week
      days_until = (day_of_week - base_time.wday) % 7
      days_until = 7 if days_until.zero? && base_time.hour >= hour
      (base_time + days_until.days).change(hour: hour, min: minute, sec: 0)
    when 'monthly'
      # Next occurrence of day_of_month
      target_date = base_time.change(day: [day_of_month, base_time.end_of_month.day].min)
      target_date = target_date.next_month if target_date <= base_time
      target_date.change(hour: hour, min: minute, sec: 0)
    end
    
    # If calculated time is in the past, add one period
    if next_run <= base_time
      next_run = case frequency
      when 'daily'
        next_run + 1.day
      when 'weekly'
        next_run + 1.week
      when 'monthly'
        next_run + 1.month
      end
    end
    
    next_run
  end
  
  def update_next_run!
    update(next_run_at: calculate_next_run)
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
  def frequency_label
    FREQUENCIES[frequency]
  end
  
  def date_range_label
    DATE_RANGE_TYPES[date_range_type]
  end
  
  def format_label
    FORMATS[format]
  end
  
  def schedule_description
    desc = case frequency
    when 'daily'
      "Every day at #{time_of_day}"
    when 'weekly'
      day_name = Date::DAYNAMES[day_of_week]
      "Every #{day_name} at #{time_of_day}"
    when 'monthly'
      "Every month on day #{day_of_month} at #{time_of_day}"
    end
    
    "#{desc} (#{date_range_label})"
  end
end
