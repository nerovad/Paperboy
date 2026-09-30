# frozen_string_literal: true

module Aim
  # What an invoice is charged to (item b.2): the encumbrance (BDO, DO, CT...),
  # the MA number, the vendor code and the chart-of-accounts coding. One line
  # normally; a split has several, and their amounts add up to the total.
  # source: rule (the one matching coding rule), person (picked from several
  # matches, or typed on the review page), fiscal (typed on the Fiscal page).
  #
  # Its whole life is audited (Aim::Audited): the lookup deletes and remakes
  # lines, so an edit trail that went with a deleted line would lose who had
  # coded the invoice before.
  class CodingLine < Record
    include Aim::CodingFields
    include Aim::Audited

    audit_record_lifecycle!

    SOURCES = %w[rule person fiscal].freeze
    # The rules' chart-of-accounts fields, with the org number after the
    # department.
    CODING_FIELDS = Aim::CodingFields::COA_FIELDS.dup.insert(2, 'org_number').freeze
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

    def blank_coding? = FIELDS.all? { |field| public_send(field).blank? }
  end
end
