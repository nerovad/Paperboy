# frozen_string_literal: true

require 'test_helper'

module Aim
  # Which agency group serves an invoice (#131): its agency's own group,
  # unless its BU is ticked into a custom group; and what a group reaches.
  class AgencyGroupsTest < ActiveSupport::TestCase
    def invoice(batch, unit, agency)
      Aim::Invoice.create!(batch_id: batch, state: 'approved', actor: 'test',
                           budget_unit: unit, agency: agency)
    end

    setup do
      @gsa = Aim::AgencyGroup.for_agency!('GSA')
      @docs = Aim::AgencyGroup.create!(name: 'GSA Documents', agency_id: 'GSA', custom: true)
      @docs.units.create!(agency_id: 'GSA', budget_unit: '4641')
    end

    test 'a BU in a custom group is that group\'s; every other is its agency\'s' do
      groups = Aim::AgencyGroups.new

      assert_equal @docs, groups.for('GSA', '4641')
      assert_equal @gsa, groups.for('GSA', '4601')
      assert_not groups.for('SHF', '2500').custom, 'an agency without a group yet gets one'
    end

    test 'the invoices of a group, as one query' do
      mine = invoice('4641.G-1', '4641', 'GSA')
      agency = invoice('4601.G-2', '4601', 'GSA')
      groups = Aim::AgencyGroups.new

      assert_equal [mine.id], groups.invoices([@docs]).pluck(:id)
      assert_equal [agency.id], groups.invoices([@gsa]).where(id: [mine.id, agency.id]).pluck(:id)
      assert_empty groups.invoices([])
    end

    test 'a custom group\'s units leave the agency\'s group' do
      groups = Aim::AgencyGroups.new

      assert_equal ['4641'], groups.units_of(@docs)
      assert_not_includes groups.units_of(@gsa), '4641'
    end

    test 'Fiscal also processes: one step, never further' do
      sheriff = Aim::AgencyGroup.for_agency!('SHF')
      @gsa.coverages.create!(covered_group: @docs)
      @docs.coverages.create!(covered_group: sheriff)
      groups = Aim::AgencyGroups.new

      assert_equal [@docs, @gsa].map(&:id).sort, groups.reach([@gsa]).map(&:id).sort
      assert_equal [@gsa], groups.covered_by(@docs)
      assert_nil groups.reach(nil)
    end

    test 'a BU sits in one custom group only, of its own agency' do
      other = Aim::AgencyGroup.create!(name: 'Elsewhere', agency_id: 'GSA', custom: true)

      assert_not other.units.build(agency_id: 'GSA', budget_unit: '4641').valid?
      assert_not other.units.build(agency_id: 'SHF', budget_unit: '2500').valid?
    end

    test 'settings default to AIM\'s and keep the report\'s order' do
      assert_equal Aim::FiscalExport::COLUMNS, @gsa.export_column_list
      assert_equal Aim::FiscalRecord::TAG_SUGGESTIONS, @gsa.tag_suggestion_list

      @gsa.update!(export_column_list: %w[Total Title Nonsense], required_field_list: %w[check_number nonsense])
      assert_equal %w[Title Total], @gsa.reload.export_column_list
      assert_equal %w[check_number], @gsa.required_field_list

      @gsa.export_column_list = []
      assert_not @gsa.valid?
    end
  end
end
