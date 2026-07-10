# frozen_string_literal: true

module DataRunner
  class Log < ApplicationRecord
    self.table_name = "datarunner_log"

    STATUSES = %w[succeeded failed].freeze

    validates :run_id, :command, :script, :status, :started_at, :completed_at, :duration_ms, presence: true
    validates :status, inclusion: { in: STATUSES }

    scope :recent_first, -> { order(started_at: :desc) }

    def self.search(filters)
      scope = recent_first
      scope = scope.where(started_at: date_range(filters[:date])) if filters[:date].present?
      scope = scope.where(command: filters[:command]) if filters[:command].present?
      scope = scope.where(selector: filters[:dsl]) if filters[:dsl].present?
      scope = scope.where(status: filters[:status]) if filters[:status].present?
      duration_scope(scope, filters[:duration])
    end

    def self.filter_options
      {
        commands: distinct_values(:command),
        dsls: distinct_values(:selector),
        statuses: distinct_values(:status)
      }
    end

    def self.date_range(value)
      date = Date.iso8601(value)
      date.all_day
    rescue Date::Error
      Time.current.all_day
    end

    def self.duration_scope(scope, duration)
      case duration
      when "under_1s" then scope.where(duration_ms: ...1_000)
      when "1s_to_10s" then scope.where(duration_ms: 1_000...10_000)
      when "10s_to_1m" then scope.where(duration_ms: 10_000...60_000)
      when "over_1m" then scope.where(duration_ms: 60_000..)
      else scope
      end
    end

    def self.distinct_values(column)
      where.not(column => [ nil, "" ]).distinct.order(column).limit(250).pluck(column)
    end
  end
end
