# frozen_string_literal: true

module SqlDashboards
  # One line of the log: somebody ran SQL, or created, changed or deleted a
  # saved query. It keeps the SQL as it was, so the row still reads after the
  # query has been edited or deleted.
  class Event < ApplicationRecord
    self.table_name = 'sql_dashboard_events'

    ACTIONS = %w[run create update delete].freeze

    validates :action, inclusion: { in: ACTIONS }

    scope :recent, -> { order(created_at: :desc, id: :desc) }

    def self.record(action, actor:, query: nil, **attributes)
      create!(
        action: action,
        sql_dashboard_query_id: query&.id,
        query_name: query&.name,
        database_key: query&.database_key,
        statement: query&.statement,
        employee_id: actor&.employee_id&.to_s,
        employee_name: [actor&.first_name, actor&.last_name].compact.join(' ').presence,
        **attributes
      )
    end
  end
end
