# frozen_string_literal: true

module Aim
  # Codes an invoice from the coding rules (item b.2). One matching rule
  # becomes the invoice's coding line; several are choices for a person, with
  # a hint when one of them is named on the invoice; none is said so. Runs
  # when an invoice reaches Ready for Approval and is looked at, and on a
  # schedule for the rest (Aim::CodeReadyJob).
  module CodingLookup
    module_function

    ACTOR = 'aim'

    def ensure!(invoice)
      return if invoice.coded? || invoice.state != 'ready_for_approval'

      run!(invoice)
    end

    def run!(invoice)
      level, rules = candidates(invoice)
      invoice.transaction do
        if rules&.one?
          line = Aim::CodingLine.from_rule(rules.first, source: 'rule', set_by: ACTOR)
          line.amount = invoice.invoice_total
          invoice.coding_lines.destroy_all
          invoice.coding_lines << line
          note = "coded from the #{level} rule for #{rules.first.vendor_name}#{" (#{rules.first.encumbrance})" if rules.first.encumbrance}"
        elsif rules
          note = "#{rules.size} coding rules match; one has to be picked"
        else
          note = "no coding rule for #{invoice.vendor_name.presence || 'this vendor'} in #{invoice.budget_unit.presence || 'its BU'}"
        end
        invoice.update_column(:coded_at, Time.current)
        invoice.events.create!(action: 'coding', actor: ACTOR, note: note)
      end
      rules
    end

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
      (Aim::CodingLine::RULE_FIELDS + %w[customer_number]).select { |f| rules.map { |r| r.public_send(f).to_s }.uniq.size > 1 }
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
