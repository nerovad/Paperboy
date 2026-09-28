# frozen_string_literal: true

module Aim
  # Codes an invoice from the coding rules (item b.2). One matching rule in
  # the invoice's BU becomes its coding line; several are choices for a
  # person, with a hint when one of them is named on the invoice; a rule from
  # another BU only ever offers (its BDO is that BU's); none is said so. Runs
  # when an invoice reaches Ready for Approval and is looked at, and on a
  # schedule for the rest (Aim::CodeReadyJob).
  module CodingLookup
    module_function

    ACTOR = 'aim'
    # Once the AI has read it, an invoice is coded wherever a person sees it.
    STATES = %w[needs_review ready_for_approval failed].freeze

    def ensure!(invoice)
      return if invoice.coded? || STATES.exclude?(invoice.state)

      run!(invoice)
    end

    def run!(invoice)
      level, rules = candidates(invoice)
      invoice.transaction do
        if rules&.one? && level != :agency
          line = Aim::CodingLine.from_rule(rules.first, source: 'rule', set_by: ACTOR)
          line.amount = invoice.invoice_total
          invoice.coding_lines.destroy_all
          invoice.coding_lines << line
          note = "coded from the #{level} rule for #{rules.first.vendor_name}#{" (#{rules.first.encumbrance})" if rules.first.encumbrance}"
        elsif rules
          where = level == :agency ? ' from other BUs' : ''
          note = "#{pluralize_rules(rules.size)}#{where} match; one has to be picked"
        else
          note = "no coding rule for #{invoice.vendor_name.presence || 'this vendor'} in #{invoice.budget_unit.presence || 'its BU'}"
        end
        invoice.update_column(:coded_at, Time.current)
        invoice.events.create!(action: 'coding', actor: ACTOR, note: note)
      end
      rules
    end

    def pluralize_rules(count) = count == 1 ? '1 coding rule' : "#{count} coding rules"

    # [level, rules] from the rules, or nil.
    def candidates(invoice)
      agency = invoice.agency!
      return if agency.blank? || invoice.vendor_name.blank?

      Aim::CodingRule.match(agency: agency, budget_unit: invoice.budget_unit, vendor_name: invoice.vendor_name,
                            customer_number: invoice.customer_number)
    end

    # A person picks one of several.
    def choose!(invoice, rule, by:)
      line = Aim::CodingLine.from_rule(rule, source: 'person', set_by: by)
      line.amount = invoice.invoice_total
      invoice.transaction do
        invoice.coding_lines.destroy_all
        invoice.coding_lines << line
        invoice.update_column(:coded_at, Time.current)
        invoice.events.create!(action: 'coding', actor: by,
                               note: "coding picked: #{rule.vendor_name}#{" (#{rule.encumbrance})" if rule.encumbrance}")
      end
      line
    end

    # The fields that differ between candidate rules: what a person looks at
    # to choose, and what the hint looks for on the invoice.
    def differing_fields(rules)
      (%w[budget_unit customer_number] + Aim::CodingLine::RULE_FIELDS).select { |f| rules.map { |r| r.public_send(f).to_s }.uniq.size > 1 }
    end

    # The candidates named on the invoice itself -- a stamp with the BDO line,
    # say -- read from the PDF's text layer when it has one (a scan does not).
    def hinted(rules, pdf_path)
      text = pdf_text(pdf_path)
      return [] if text.blank?

      fields = differing_fields(rules)
      rules.select do |rule|
        fields.any? { |f| (v = rule.public_send(f).to_s.strip).length >= 4 && text.include?(v.downcase) }
      end
    end

    def pdf_text(path)
      return if path.blank? || !File.file?(path)

      PDF::Reader.new(path).pages.map(&:text).join("\n").downcase
    rescue StandardError
      nil
    end
  end
end
