# frozen_string_literal: true

module Aim
  # One change to a coding rule: created, updated (one row per field),
  # retired, restored or undone. Written once and never changed.
  class CodingRuleChange < Record
    KINDS = %w[created updated retired restored undone].freeze

    belongs_to :coding_rule, class_name: 'Aim::CodingRule', inverse_of: :changes_made

    validates :kind, inclusion: { in: KINDS }
    validates :changed_by, presence: true

    def readonly? = persisted? || super
  end
end
