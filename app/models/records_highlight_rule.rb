# frozen_string_literal: true

# One colouring rule on a Records table: rows whose column meets the condition
# are shaded, e.g. Fleet Vehicles' Last Updated "on or before 12/15/2025" in
# red, labelled "Out of compliance". Rules belong to the table, not a person,
# so everyone who opens it sees the same colours; the table's editors manage
# them from the grid. A table's rules are checked in position order and the
# first that matches colours the row (see RecordsHighlights). The condition
# itself is RecordsCondition, shared with RecordsEmailRule.
class RecordsHighlightRule < ApplicationRecord
  include RecordsCondition

  COLORS = { 'red' => 'Red', 'amber' => 'Amber', 'green' => 'Green', 'blue' => 'Blue' }.freeze

  validates :color, inclusion: { in: COLORS.keys }
  validates :label, length: { maximum: 60 }

  scope :for_table, ->(slug) { where(table_slug: slug).order(:position, :id) }

  def display_label
    label.presence || description
  end
end
