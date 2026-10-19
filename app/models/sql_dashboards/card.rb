# frozen_string_literal: true

module SqlDashboards
  # One saved query placed on one dashboard.
  class Card < ApplicationRecord
    self.table_name = 'sql_dashboard_cards'

    WIDTHS = { 'half' => 'Half width', 'full' => 'Full width' }.freeze

    belongs_to :dashboard, class_name: 'SqlDashboards::Dashboard', foreign_key: :sql_dashboard_id,
                           inverse_of: :cards
    belongs_to :query, class_name: 'SqlDashboards::Query', foreign_key: :sql_dashboard_query_id,
                       inverse_of: :cards

    validates :width, inclusion: { in: WIDTHS.keys }

    # Swaps places with the card before (-1) or after (+1) it. A card already
    # at that end stays where it is.
    def move(direction)
      siblings = dashboard.cards.to_a
      from = siblings.index(self)
      to = from + direction
      return unless to.between?(0, siblings.size - 1)

      siblings[from], siblings[to] = siblings[to], siblings[from]
      transaction do
        siblings.each_with_index { |card, at| card.update!(position: at + 1) }
      end
    end
  end
end
