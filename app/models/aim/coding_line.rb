# frozen_string_literal: true

module Aim
  # What an invoice is charged to (item b.2): the encumbrance (BDO, DO, CT...),
  # the MA number, the vendor code and the chart-of-accounts coding. One line
  # normally; a split has several, and their amounts add up to the total.
  # source: rule (the one matching coding rule), person (picked from several
  # matches, or typed on the review page), fiscal (typed on the Fiscal page).
  class CodingLine < Record
    SOURCES = %w[rule person fiscal].freeze
    CODING_FIELDS = %w[fund department org_number object_code dept_object activity function_code major_program program
                       phase task].freeze
    FIELDS = (%w[encumbrance_type encumbrance_number ma_number vendor_code] + CODING_FIELDS).freeze
    # What a coding rule supplies (rules carry no org number).
    RULE_FIELDS = (FIELDS - %w[org_number]).freeze
    EDITABLE_FIELDS = (FIELDS + %w[amount]).freeze

    belongs_to :invoice, class_name: 'Aim::Invoice', inverse_of: :coding_lines
    belongs_to :coding_rule, class_name: 'Aim::CodingRule', optional: true

    validates :line_no, presence: true
    validates :source, inclusion: { in: SOURCES }

    def self.from_rule(rule, source:, set_by:)
      new(rule.attributes.slice(*RULE_FIELDS).merge(coding_rule: rule, source: source, set_by: set_by, warnings: rule.warnings))
    end

    def encumbrance = [encumbrance_type, encumbrance_number].compact_blank.join('_').presence

    def encumbrance=(value)
      type, number = value.to_s.strip.match(/\A([A-Za-z]{2,4})_?(.*)\z/)&.captures
      self.encumbrance_type = type&.upcase
      self.encumbrance_number = number.presence
    end

    def blank_coding? = FIELDS.all? { |field| public_send(field).blank? }
  end
end
