# frozen_string_literal: true

# The "run this for me every Monday at 07:00" half of a scheduled delivery,
# shared by ScheduledReport (form submissions over a date range) and
# ScheduledRecordExport (a Records grid view). The including model owns what
# gets delivered; this owns when, and the columns it needs are the same on
# both tables: employee_id, frequency, time_of_day, day_of_week, day_of_month,
# enabled, last_run_at and next_run_at.
#
# ScheduledReportsRunnerJob polls every minute and executes whatever is #due.
module RecurringSchedule
  extend ActiveSupport::Concern

  FREQUENCIES = {
    'daily' => 'Every day',
    'weekly' => 'Weekly',
    'monthly' => 'Monthly'
  }.freeze

  # Schedules are entered, and run, in county time whatever the server's zone.
  TIME_ZONE = 'Pacific Time (US & Canada)'

  included do
    validates :employee_id, presence: true
    validates :frequency, presence: true, inclusion: { in: FREQUENCIES.keys }
    validates :time_of_day, presence: true, format: { with: /\A\d{2}:\d{2}\z/, message: 'must be in HH:MM format' }

    validates :day_of_week, inclusion: { in: 0..6 }, if: -> { frequency == 'weekly' }
    validates :day_of_month, inclusion: { in: 1..31 }, if: -> { frequency == 'monthly' }

    scope :enabled, -> { where(enabled: true) }
    scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }
    scope :due, -> { enabled.where('next_run_at <= ?', Time.current) }
  end

  def employee
    Employee.find_by(employee_id: employee_id)
  end

  def calculate_next_run
    base_time = Time.current.in_time_zone(TIME_ZONE)
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

  def frequency_label
    FREQUENCIES[frequency]
  end

  # "Every Monday at 07:00" -- when it runs, without what it delivers.
  def timing_description
    case frequency
    when 'daily'
      "Every day at #{time_of_day}"
    when 'weekly'
      "Every #{Date::DAYNAMES[day_of_week]} at #{time_of_day}"
    when 'monthly'
      "Every month on day #{day_of_month} at #{time_of_day}"
    end
  end
end
