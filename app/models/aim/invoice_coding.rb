# frozen_string_literal: true

module Aim
  # An invoice's coding lines and agency (item b.2). Included by Aim::Invoice.
  module InvoiceCoding
    extend ActiveSupport::Concern

    included do
      has_many :coding_lines, -> { order(:line_no) }, class_name: 'Aim::CodingLine', inverse_of: :invoice,
                                                      dependent: :destroy
    end

    # The COA agency the budget unit belongs to, kept once found: three unit
    # numbers belong to more than one agency, so this must be a fact on the
    # row, not a guess each time (item k).
    def agency!
      return agency if agency.present?

      found = Aim::Units.new.agency_of(budget_unit)
      update_column(:agency, found) if found && persisted?
      found
    end

    def coded? = coded_at.present?

    def coding = coding_lines.first

    # A change to what the rules match on makes the coding a question again,
    # unless a person already chose or typed it.
    def forget_rule_coding!
      return unless coding_lines.all? { |line| line.source == 'rule' }

      coding_lines.destroy_all
      update_column(:coded_at, nil)
    end
  end
end
