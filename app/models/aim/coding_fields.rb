# frozen_string_literal: true

module Aim
  # What coding rules and coding lines share (item b): the chart-of-accounts
  # fields, and the encumbrance as one value -- BDO_4640..., DO_..., CT_... --
  # over the two columns it is kept in. Included by Aim::CodingRule and
  # Aim::CodingLine; Aim::LookupFile reads a file's encumbrance the same way.
  module CodingFields
    extend ActiveSupport::Concern

    # The chart-of-accounts fields a rule supplies, in the order they are
    # shown. A coding line has an org number besides (Aim::CodingLine).
    COA_FIELDS = %w[fund department object_code dept_object activity function_code major_program program phase
                    task].freeze

    # A type of two to four letters, an optional underscore, then the number.
    ENCUMBRANCE = /\A([A-Za-z]{2,4})_?(.*)\z/

    # [type, number] for an encumbrance as typed ("bdo_4640..." gives
    # ["BDO", "4640..."]), or [nil, nil] when it is not one.
    def self.split_encumbrance(value)
      type, number = value.to_s.strip.match(ENCUMBRANCE)&.captures
      [type&.upcase, number.presence]
    end

    def encumbrance = [encumbrance_type, encumbrance_number].compact_blank.join('_').presence

    def encumbrance=(value)
      self.encumbrance_type, self.encumbrance_number = CodingFields.split_encumbrance(value)
    end
  end
end
