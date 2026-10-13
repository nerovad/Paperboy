# frozen_string_literal: true

module SqlDashboards
  # Saved SQL, the database it runs against and the chart it draws.
  class Query < ApplicationRecord
    self.table_name = 'sql_dashboard_queries'

    CHART_TYPES = {
      'table' => 'Table',
      'bar' => 'Bar chart',
      'line' => 'Line chart',
      'pie' => 'Pie chart',
      'scatter' => 'Scatter plot'
    }.freeze

    has_many :cards, class_name: 'SqlDashboards::Card', foreign_key: :sql_dashboard_query_id,
                     dependent: :destroy, inverse_of: :query

    validates :name, :statement, presence: true
    validates :database_key, inclusion: { in: ->(_) { Database.keys } }
    validates :chart_type, inclusion: { in: CHART_TYPES.keys }

    scope :alphabetical, -> { order(:name) }

    def to_s = name

    def database
      Database.find(database_key)
    end

    # What the log calls the change a save is about to make, or nil when the
    # save changes nothing worth a row.
    def pending_change
      return 'create' if new_record?

      'update' if (changed & %w[name description database_key chart_type statement]).any?
    end
  end
end
