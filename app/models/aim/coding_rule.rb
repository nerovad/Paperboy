# frozen_string_literal: true

module Aim
  # What a vendor's invoices in a budget unit are coded with (item b): the
  # encumbrance (BDO, DO, CT...), the MA number and the chart-of-accounts
  # coding. Matched most specific first: vendor and customer number within
  # the BU, then vendor within the BU, then vendor anywhere in the agency.
  # Several rules at one level are choices for a person, never a pick.
  #
  # A rule is in effect from effective_from until effective_until (open when
  # nil). Nothing is deleted: a rule that no longer applies is retired, and
  # every change is an Aim::CodingRuleChange.
  class CodingRule < Record
    CODING_FIELDS = %w[fund department object_code dept_object activity function_code major_program program phase
                       task].freeze
    FIELDS = (%w[budget_unit vendor_name customer_number encumbrance_type encumbrance_number ma_number vendor_code] +
              CODING_FIELDS + %w[notes effective_from effective_until]).freeze

    belongs_to :import, class_name: 'Aim::CodingImport', optional: true, inverse_of: :rules
    belongs_to :retired_by_import, class_name: 'Aim::CodingImport', optional: true, inverse_of: :retired_rules
    has_many :changes_made, -> { order(:created_at, :id) }, class_name: 'Aim::CodingRuleChange',
                                                            inverse_of: :coding_rule, dependent: :restrict_with_exception

    validates :agency, :budget_unit, :vendor_name, :effective_from, presence: true
    validates :budget_unit, format: { with: /\A\d{4}\z/ }
    before_validation { self.vendor_key = self.class.key_for(vendor_name) }

    scope :in_effect, lambda { |on = Date.current|
      where('effective_from <= ?', on).where('effective_until IS NULL OR effective_until >= ?', on)
    }
    scope :for_agency, ->(agency) { where(agency: agency) }

    def self.key_for(name) = name.to_s.squish.downcase

    # The rules for an invoice, most specific level first, as
    # [level, [rules]]; nil when nothing matches. level: :customer, :unit or
    # :agency.
    def self.match(agency:, budget_unit:, vendor_name:, customer_number: nil, on: Date.current)
      key = key_for(vendor_name)
      return if key.blank?

      rules = in_effect(on).for_agency(agency).where(vendor_key: key).to_a
      in_unit = rules.select { |rule| rule.budget_unit == budget_unit.to_s }
      if customer_number.present?
        exact = in_unit.select { |rule| rule.customer_number.to_s.casecmp?(customer_number.to_s.strip) }
        return [:customer, exact] if exact.any?
      end
      return [:unit, in_unit] if in_unit.any?

      [:agency, rules] if rules.any?
    end

    def in_effect?(on = Date.current) = effective_from <= on && (effective_until.nil? || effective_until >= on)

    def encumbrance = [encumbrance_type, encumbrance_number].compact_blank.join('_').presence

    def encumbrance=(value)
      type, number = value.to_s.strip.match(/\A([A-Za-z]{2,4})_?(.*)\z/)&.captures
      self.encumbrance_type = type&.upcase
      self.encumbrance_number = number.presence
    end

    # The same coding and encumbrance as another rule: a second import of an
    # unchanged row.
    def same_as?(other)
      (CODING_FIELDS + %w[encumbrance_type encumbrance_number ma_number customer_number]).all? do |field|
        public_send(field).to_s == other.public_send(field).to_s
      end
    end

    def retire!(on:, by:, kind: 'retired', import_id: nil)
      record_change(kind, 'effective_until', effective_until, on, by)
      update!(effective_until: on, updated_by: by, retired_by_import_id: import_id)
    end

    def restore!(by:)
      record_change('restored', 'effective_until', effective_until, nil, by)
      update!(effective_until: nil, retired_by_import_id: nil, updated_by: by)
    end

    # Edits from the screen: one change row per field that differs.
    def apply_edits!(attributes, by:)
      transaction do
        assign_attributes(attributes)
        changed_fields = changes.keys & FIELDS
        changed_fields.each { |field| record_change('updated', field, changes[field][0], changes[field][1], by) }
        self.updated_by = by
        save!
      end
    end

    def record_change(kind, field, before, after, by)
      changes_made.build(kind: kind, field: field, before: before&.to_s, after: after&.to_s, changed_by: by)
    end
  end
end
