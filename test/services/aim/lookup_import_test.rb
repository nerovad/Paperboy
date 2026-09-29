# frozen_string_literal: true

require 'test_helper'

module Aim
  # Fiscal's lookup files as coding rules (item b): read whatever the file
  # calls its columns, put the known slips right, refuse what the COA does
  # not know, and load as an import that can be undone.
  class LookupImportTest < ActiveSupport::TestCase
    HEADER = 'Vendor Name,AIM Unique Identifier,Fiscal Unique Identifier,Fund,Department,' \
             '"Encumbrance Doc (BDO, DO, etc)",Budget Unit,Object,Activity,Function,Program,Phase,Task,' \
             'Approver Name,Fusion Queue,Keywords'

    setup { @dir = Dir.mktmpdir }
    teardown { FileUtils.rm_rf(@dir) }

    def file(name, *lines)
      path = File.join(@dir, name)
      File.write(path, ([HEADER] + lines).join("\n"))
      path
    end

    test 'reads the file, tidies the slips, and refuses what the COA does not know' do
      path = file('Business Support.csv',
                  'FAST SIGNS,,,,,BDO_46402023072600000005_1,4641,2162,GATV,GFUN,INDIRECT,,,,92,',
                  'Parks Co,,,VC00017299,,,4641,2192 TEMP HELP,GATV,GFUN,INDIRECT,,,,,',
                  'Bad Object,,,,,BDO_46402023072600000006_1,4641,22304,GATV,GFUN,INDIRECT,,,,,',
                  ',,,,,BDO_46402023072600000007_1,4641,2162,,,,,,,,',
                  'Nothing Co,,,,,,4641,,,,,,,,,')
      import = Aim::LookupImport.new(path, agency: 'GSA')
      report = import.report

      assert_equal [5, 2, 3], report.values_at(:rows, :loadable, :refused)
      assert_equal ['object code "22304" is not in the COA for GSA'], report[:refused_rows][0][:reasons]
      assert_equal ['no vendor name'], report[:refused_rows][1][:reasons]
      assert_equal ['no coding and no encumbrance'], report[:refused_rows][2][:reasons]
      fast, parks = import.loadable.map(&:rule)
      assert_equal %w[BDO 46402023072600000005_1], [fast.encumbrance_type, fast.encumbrance_number]
      assert_equal Date.new(2023, 7, 26), fast.effective_from
      assert_equal %w[2192 VC00017299], [parks.object_code, parks.vendor_code]
      assert_equal Date.current, parks.effective_from
      assert_includes report[:noted_rows].last[:notes], 'object read from "2192 TEMP HELP"'
    end

    test 'a row the COA objects to can be accepted, and carries the objection; a row with no vendor cannot' do
      path = file('c.csv',
                  'Bad Object,,,,,BDO_46402023072600000006_1,4641,22304,GATV,GFUN,INDIRECT,,,,,',
                  ',,,,,BDO_46402023072600000007_1,4641,2162,,,,,,,,')
      report = Aim::LookupImport.new(path, agency: 'GSA').report
      assert_equal([true, false], report[:refused_rows].map { |r| r[:acceptable] })

      import = Aim::LookupImport.new(path, agency: 'GSA', accept: [2]).apply!(by: 'fiscal@example.com')

      assert_equal [1, 1], [import.loaded_count, import.refused_count]
      assert_equal 'object code "22304" is not in the COA for GSA', import.rules.first.warnings
      assert_equal 1, Aim::LookupImport.new(path, agency: 'GSA', accept: :all).loadable.size
    end

    test 'applying loads the rules once, replaces changed ones, and undo puts it all back' do
      path = file('a.csv', 'FAST SIGNS,,,,,BDO_46402023072600000005_1,4641,2162,GATV,GFUN,INDIRECT,,,,,')
      first = Aim::LookupImport.new(path, agency: 'GSA').apply!(by: 'fiscal@example.com')
      assert_equal 1, first.loaded_count
      assert_equal 0, Aim::LookupImport.new(path, agency: 'GSA').apply!(by: 'fiscal@example.com').loaded_count

      noted = file('n.csv', 'FAST SIGNS,,,,,BDO_46402023072600000005_1,4641,2162,GATV,GFUN,INDIRECT,,,,,call first')
      assert_equal(%w[edit], Aim::LookupImport.new(noted, agency: 'GSA').report[:all_rows].map { |r| r[:kind] })
      assert_equal 1, Aim::LookupImport.new(noted, agency: 'GSA').apply!(by: 'fiscal@example.com').loaded_count

      changed = file('b.csv', 'Fast Signs,,,,,BDO_46402024072600000009_1,4641,2199,GATV,GFUN,INDIRECT,,,,,')
      report = Aim::LookupImport.new(changed, agency: 'GSA').report
      assert_equal [0, 1, 0], report.values_at(:adds, :edits, :unchanged)
      second = Aim::LookupImport.new(changed, agency: 'GSA').apply!(by: 'fiscal@example.com')
      assert_equal [1, 1], [second.loaded_count, second.retired_count]
      old, new = Aim::CodingRule.order(:id).to_a.values_at(1, 2)
      assert_equal Date.new(2024, 7, 25), old.effective_until
      assert_equal [:unit, [new]], Aim::CodingRule.match(agency: 'GSA', budget_unit: '4641', vendor_name: 'fast signs ')

      second.undo!(by: 'admin@example.com')
      assert_nil old.reload.effective_until
      assert_not new.reload.in_effect?
      assert_equal %w[created retired restored], old.changes_made.map(&:kind)
      assert_equal %w[created retired], Aim::CodingRule.order(:id).first.changes_made.map(&:kind)
    end

    test 'a vendor listed twice in one file loads as two choices, neither retiring the other' do
      path = file('d.csv',
                  'AAA Propane,,,,,BDO_47002024072900000003_1,4703,2104,GATV,GFUN,MNTFIRE,,,,,',
                  'AAA Propane,,,,,BDO_47002024072900000003_2,4703,2104,GATV,GFUN,MNTFIRE,,,,,')
      import = Aim::LookupImport.new(path, agency: 'GSA').apply!(by: 'fiscal@example.com')

      assert_equal [2, 0], [import.loaded_count, import.retired_count]
      assert_equal 2, Aim::CodingRule.match(agency: 'GSA', budget_unit: '4703', vendor_name: 'AAA Propane').last.size
    end

    test 'the most specific rule wins: customer within the BU, then the BU, then the agency' do
      rows = [%w[Vestis 4721 6063764 BDO_1], %w[Vestis 4721 6063751 BDO_2], ['Vestis', '4723', nil, 'BDO_3']]
      rows.each do |vendor, unit, customer, enc|
        Aim::CodingRule.create!(agency: 'GSA', budget_unit: unit, vendor_name: vendor, customer_number: customer,
                                encumbrance_type: 'BDO', encumbrance_number: enc, effective_from: Date.new(2024, 7, 1))
      end

      level, rules = Aim::CodingRule.match(agency: 'GSA', budget_unit: '4721', vendor_name: 'VESTIS', customer_number: '6063751')
      assert_equal [:customer, %w[BDO_2]], [level, rules.map(&:encumbrance_number)]
      level, rules = Aim::CodingRule.match(agency: 'GSA', budget_unit: '4721', vendor_name: 'Vestis')
      assert_equal [:unit, 2], [level, rules.size]
      level, rules = Aim::CodingRule.match(agency: 'GSA', budget_unit: '4601', vendor_name: 'Vestis')
      assert_equal [:agency, 3], [level, rules.size]
      assert_nil Aim::CodingRule.match(agency: 'GSA', budget_unit: '4601', vendor_name: 'Nobody')
    end
  end
end
