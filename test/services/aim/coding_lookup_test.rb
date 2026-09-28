# frozen_string_literal: true

require 'test_helper'
require 'prawn'

module Aim
  # Coding an invoice from the rules (item b.2): one match is its line,
  # several are choices with a hint from the PDF's text, none is said so.
  class CodingLookupTest < ActiveSupport::TestCase
    def rule(enc, **attrs)
      Aim::CodingRule.create!(agency: 'GSA', budget_unit: '4641', vendor_name: 'ACME', encumbrance: enc,
                              object_code: '2162', effective_from: Date.new(2024, 7, 1), **attrs)
    end

    def invoice(**attrs)
      Aim::Invoice.create!(batch_id: "4641.#{SecureRandom.hex(3)}", state: 'ready_for_approval', actor: 'test',
                           document_type: 'Invoice', vendor_name: 'acme', invoice_number: 'A-1', budget_unit: '4641',
                           invoice_total: 12.5, **attrs)
    end

    test 'one matching rule becomes the coding line, and the agency is kept on the row' do
      only = rule('BDO_46402024072600000001_1', warnings: 'object code "2162" is odd')
      row = invoice

      assert_equal [only], Aim::CodingLookup.run!(row)

      line = row.coding
      assert_equal ['BDO_46402024072600000001_1', '2162', 'rule', 12.5, only.id], [line.encumbrance, line.object_code, line.source, line.amount, line.coding_rule_id]
      assert_equal 'object code "2162" is odd', line.warnings
      assert_equal 'GSA', row.reload.agency
      assert row.coded?
      assert_match(/coded from the unit rule for ACME/, row.events.last.note)
    end

    test 'a rule from another BU is offered, never applied on its own' do
      other = rule('BDO_47002024072900000051_1', budget_unit: '4703')
      row = invoice

      assert_equal [other], Aim::CodingLookup.run!(row)
      assert_empty row.coding_lines
      assert_match(/1 coding rule from other BUs match/, row.events.last.note)
      assert_equal %w[budget_unit], Aim::CodingLookup.differing_fields([other, rule('BDO_47002024072900000051_1', budget_unit: '4705')])
    end

    test 'several matches leave the choice to a person, who picks one' do
      first = rule('BDO_46402024072600000001_1')
      rule('BDO_46402024072600000001_2')
      row = invoice

      rules = Aim::CodingLookup.run!(row)
      assert_equal 2, rules.size
      assert row.coded?
      assert_empty row.coding_lines
      assert_equal %w[encumbrance_number], Aim::CodingLookup.differing_fields(rules)

      Aim::CodingLookup.choose!(row, first, by: 'jane@example.com')
      assert_equal ['BDO_46402024072600000001_1', 'person', 'jane@example.com'],
                   [row.coding.encumbrance, row.coding.source, row.coding.set_by]
    end

    test 'a candidate named in the PDF text is hinted' do
      hinted = rule('BDO_46402024072600000001_1')
      rule('BDO_46402024072600000001_2')
      path = File.join(Dir.mktmpdir, 'stamped.pdf')
      Prawn::Document.generate(path) { |pdf| pdf.text 'Charge to BDO_46402024072600000001_1 please' }

      assert_equal [hinted], Aim::CodingLookup.hinted(Aim::CodingRule.all.to_a, path)
      assert_empty Aim::CodingLookup.hinted(Aim::CodingRule.all.to_a, '/nowhere.pdf')
    end

    test 'no match is recorded as such, and a changed vendor asks again' do
      row = invoice
      assert_nil Aim::CodingLookup.run!(row)
      assert row.coded?
      assert_match(/no coding rule for acme in 4641/, row.events.last.note)

      rule('BDO_46402024072600000001_1')
      row.forget_rule_coding!
      assert_not row.reload.coded?
      Aim::CodingLookup.ensure!(row)
      assert_equal 'rule', row.coding.source
    end

    test 'the job codes what is waiting' do
      rule('BDO_46402024072600000001_1')
      row = invoice
      invoice(state: 'needs_review', document_type: 'Invoice')

      Aim::CodeReadyJob.perform_now

      assert row.reload.coded?
      assert_equal 1, Aim::Invoice.where(coded_at: nil).count
    end
  end
end
