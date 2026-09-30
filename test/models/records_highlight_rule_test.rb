# frozen_string_literal: true

require 'test_helper'

class RecordsHighlightRuleTest < ActiveSupport::TestCase
  def rule(**attrs)
    RecordsHighlightRule.new({ table_slug: 'fleet', column_name: 'updated_at', operator: 'on_or_before',
                               value: '2025-12-15', color: 'red' }.merge(attrs))
  end

  def pacific(*args) = Time.find_zone('Pacific Time (US & Canada)').local(*args)

  test 'dates compare on the Pacific day the grid shows' do
    cutoff = rule

    assert cutoff.matches?(pacific(2025, 12, 15, 23, 30))
    assert_not cutoff.matches?(pacific(2025, 12, 16, 0, 5))
    # 07:00 UTC on the 16th is still the 15th in Ventura.
    assert cutoff.matches?(Time.utc(2025, 12, 16, 7, 0))
  end

  test 'before and after exclude the day itself; on-or variants include it' do
    day = pacific(2025, 12, 15, 12)

    assert_not rule(operator: 'before').matches?(day)
    assert rule(operator: 'on_or_after').matches?(day)
    assert_not rule(operator: 'after').matches?(day)
  end

  test 'older than N days counts back from today' do
    stale = rule(operator: 'older_than_days', value: '30')

    travel_to pacific(2026, 9, 30, 9) do
      assert stale.matches?(pacific(2026, 8, 30, 9))
      assert_not stale.matches?(pacific(2026, 8, 31, 9))
    end
  end

  test 'a blank date never matches a date condition' do
    assert_not rule.matches?(nil)
  end

  test 'text conditions ignore case' do
    make = rule(column_name: 'make', operator: 'contains', value: 'chev')

    assert make.matches?('CHEVROLET')
    assert rule(column_name: 'make', operator: 'equals', value: 'ford').matches?('FORD')
    assert rule(column_name: 'make', operator: 'blank', value: nil).matches?('')
  end

  test 'validates the column, the condition for its kind, and the value' do
    assert rule.valid?
    assert_not rule(column_name: 'nope').valid?
    assert_not rule(column_name: 'make', operator: 'before').valid?
    assert_not rule(operator: 'contains', value: 'x').valid?
    assert_not rule(value: 'not a date').valid?
    assert_not rule(operator: 'older_than_days', value: '0').valid?
    assert_not rule(color: 'purple').valid?
  end

  test 'describes itself in the grid vocabulary' do
    assert_equal 'Last Updated is on or before 12/15/2025', rule.description
    assert_equal 'Out of compliance', rule(label: 'Out of compliance').display_label
  end

  test 'the first matching rule in position order colours a row' do
    table = RegistryTable.find('fleet')
    stale = RecordsHighlightRule.create!(table_slug: 'fleet', column_name: 'updated_at', operator: 'on_or_before',
                                         value: '2025-12-15', color: 'red', position: 0)
    chevy = RecordsHighlightRule.create!(table_slug: 'fleet', column_name: 'make', operator: 'equals',
                                         value: 'CHEV', color: 'blue', position: 1)
    old_chevy = FleetVehicle.new(make: 'CHEV', updated_at: pacific(2025, 1, 1, 12))
    new_chevy = FleetVehicle.new(make: 'CHEV', updated_at: pacific(2026, 1, 1, 12))
    new_ford = FleetVehicle.new(make: 'FORD', updated_at: pacific(2026, 1, 1, 12))
    highlights = RecordsHighlights.new(table)

    matched = [old_chevy, new_chevy, new_ford].map { |row| highlights.rule_for(row) }

    assert_equal [stale, chevy, nil], matched
    assert_equal({ stale => 1, chevy => 1 }, highlights.counts([old_chevy, new_chevy, new_ford]))
    assert_equal [old_chevy], highlights.rows_for([old_chevy, new_chevy, new_ford], stale.id)
    assert_equal 3, highlights.rows_for([old_chevy, new_chevy, new_ford], 0).size
  end
end
