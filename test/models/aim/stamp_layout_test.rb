# frozen_string_literal: true

require 'test_helper'

module Aim
  # An agency group's stamp layout (#221): its areas, its history, and the
  # stamp AIM always wrote when nobody has saved one.
  class StampLayoutTest < ActiveSupport::TestCase
    def group(name = 'Fiscal Group', agency: 'GSA') = Aim::AgencyGroup.create!(name: name, agency_id: agency, custom: true)

    def layout(group = nil, rows: ['{approver}'], **area)
      Aim::StampLayout.create!(agency_group: group, created_by: 'fiscal@example.com',
                               area_list: [{ 'name' => 'Approval', 'rows' => rows }.merge(area.stringify_keys)])
    end

    def values(**overrides)
      { 'received' => Time.zone.local(2025, 6, 24, 8), 'invoice_date' => Date.new(2025, 6, 16),
        'approver' => 'Martinez, Mark', 'approved_at' => Time.zone.local(2025, 6, 27, 12, 27, 3) }.merge(overrides)
    end

    test 'with nothing saved, the stamp is the one AIM always wrote' do
      boxes = Aim::StampLayout.current_for(nil).boxes(values)

      assert_predicate Aim::StampLayout.current_for(nil), :built_in?
      assert_equal 1, boxes.size
      assert_equal ['06/24/2025- Invoice Date:20250616', 'Martinez, Mark_06/27/2025_12:27:03'], boxes.first.lines
      assert_equal ['bottom_right', 7.0, 'helvetica', 'right', '#ffffff'],
                   [boxes.first.anchor, boxes.first.size, boxes.first.font, boxes.first.align, boxes.first.background]
    end

    test 'the high-dollar first approval adds its row only when there is one' do
      with_first = values('first_approver' => 'Lee, Sam', 'first_approved_at' => Time.zone.local(2025, 6, 26, 9, 5))

      lines = Aim::StampLayout.built_in.boxes(with_first).first.lines

      assert_equal ['06/24/2025- Invoice Date:20250616', '1st: Lee, Sam_06/26/2025_09:05:00',
                    'Martinez, Mark_06/27/2025_12:27:03'], lines
    end

    test 'a group uses its own newest layout, then the default, then the built-in one' do
      own = group('Own')
      other = group('Other')
      default = layout(rows: ['DEFAULT {approver}'])
      layout(own, rows: ['OLD {approver}'])
      newest = layout(own, rows: ['NEW {approver}'])

      assert_equal newest, Aim::StampLayout.current_for(own)
      assert_equal default, Aim::StampLayout.current_for(other)
      assert_equal 2, Aim::StampLayout.history_for(own).count
    end

    test 'several areas are written in the one stamping; an area with nothing to say is dropped' do
      saved = Aim::StampLayout.create!(created_by: 'x', area_list: [
                                         { 'rows' => ['{approver}'] },
                                         { 'rows' => ['Budget Unit # {budget_unit}', 'Check # {check_number}'],
                                           'anchor' => 'top_left' },
                                         { 'rows' => ['{check_number}'] }
                                       ])

      boxes = saved.boxes(values('budget_unit' => '4641'))

      assert_equal [['Martinez, Mark'], ['Budget Unit # 4641']], boxes.map(&:lines), 'no check number yet: that row waits'
      assert_equal 'top_left', boxes.second.anchor
    end

    test 'a layout must have an area with text, and may name only known fields' do
      empty = Aim::StampLayout.new(created_by: 'x', area_list: [])
      unknown = Aim::StampLayout.new(created_by: 'x', area_list: [{ 'rows' => ['{approver} {salary}'] }])

      assert_not empty.valid?
      assert_not unknown.valid?
      assert_includes unknown.errors.full_messages.join, 'unknown fields: salary.'
    end

    test 'a saved layout is never changed, only followed by a newer one' do
      saved = layout

      assert_raises(ActiveRecord::ReadOnlyRecord) { saved.update!(note: 'edited') }
    end
  end
end
