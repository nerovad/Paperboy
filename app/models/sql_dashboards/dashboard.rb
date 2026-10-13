# frozen_string_literal: true

module SqlDashboards
  # A named page of cards.
  class Dashboard < ApplicationRecord
    self.table_name = 'sql_dashboards'

    has_many :cards, -> { order(:position, :id) }, class_name: 'SqlDashboards::Card',
                                                   foreign_key: :sql_dashboard_id,
                                                   dependent: :destroy, inverse_of: :dashboard

    validates :name, presence: true

    scope :alphabetical, -> { order(:name) }

    def to_s = name

    def next_position
      (cards.maximum(:position) || 0) + 1
    end
  end
end
