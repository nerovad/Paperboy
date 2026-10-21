# frozen_string_literal: true

require 'test_helper'

module Aim
  # The stamp designer's values (#221): samples read like real coding, each in
  # its own field; the worst case is every field at its longest.
  class StampFieldsTest < ActiveSupport::TestCase
    def rule(vendor, agency: 'GSA', **coding)
      Aim::CodingRule.create!(agency: agency, budget_unit: '4641', vendor_name: vendor, effective_from: Date.new(2026, 1, 1),
                              **coding)
    end

    test 'every coding field is offered, in the chart of accounts order' do
      coding = Aim::StampFields::FIELDS.select { |_, field| field[:group] == 'Coding' }.keys

      assert_equal %w[encumbrance ma_number vendor_code fund department object_code dept_object activity function_code
                      major_program program phase task], coding
      assert_equal 'Function', Aim::StampFields::FIELDS.dig('function_code', :label)
    end

    test "samples are GSA's fullest real coding rule, each code in its own field" do
      rule('Thin', fund: 'G001')
      rule('Fuller elsewhere', agency: 'SHF', fund: 'S040', department: 'SHF', object_code: '2199', activity: 'GATV',
                               function_code: 'GFUN', major_program: 'JBCT', program: '20JBCT', phase: 'DRUGAB', task: 'T1')
      rule('CFMG', encumbrance: 'PD_25502023081800000001', fund: 'S040', department: 'SHF', object_code: '2199',
                   activity: 'GATV', function_code: 'GFUN', major_program: 'JBCT', program: '20JBCT', phase: 'DRUGAB')

      samples = Aim::StampFields.samples

      assert_equal %w[CFMG 4641 S040 GATV GFUN JBCT 20JBCT DRUGAB PD_25502023081800000001],
                   samples.values_at('vendor', 'budget_unit', 'fund', 'activity', 'function_code', 'major_program',
                                     'program', 'phase', 'encumbrance')
    end

    test "another agency's samples are its own rules" do
      rule('Jail supplies', agency: 'SHF', fund: 'S040')

      assert_equal ['Jail supplies', 'S040'], Aim::StampFields.samples(agency: 'SHF').values_at('vendor', 'fund')
    end

    test 'without coding rules the samples still read like real codes' do
      assert_equal %w[GFUN INDIRECT GATV], Aim::StampFields.samples.values_at('function_code', 'program', 'activity')
    end

    test 'the worst case takes each coding field at its longest real value' do
      rule('A', program: 'CIVIL', major_program: 'DETSRV')
      rule('B', program: 'BSSTORESLS', major_program: 'INM')

      worst = Aim::StampFields.worst_case

      assert_equal %w[BSSTORESLS DETSRV], worst.values_at('program', 'major_program')
      assert_equal 'Montgomery-Fitzgerald, Alexandria Catherine', worst['approver']
    end
  end
end
