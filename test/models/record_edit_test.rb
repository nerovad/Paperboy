# frozen_string_literal: true

require 'test_helper'

class RecordEditTest < ActiveSupport::TestCase
  def row
    @row ||= PcardInventory.create!(first_name: 'Ada', last_name: 'Lovelace', monthly_limit: 100)
  end

  test 'capture records the before and after values' do
    edit = RecordEdit.capture(row: row, table_slug: 'pcard', column_name: 'monthly_limit',
                              old_value: 100, new_value: 250)

    assert_predicate edit, :persisted?
    assert_equal '100', edit.old_value
    assert_equal '250', edit.new_value
    assert_equal 'monthly_limit', edit.column_name
    assert_equal 'pcard', edit.table_slug
  end

  test 'capture points back at the edited row' do
    edit = RecordEdit.capture(row: row, table_slug: 'pcard', column_name: 'first_name',
                              old_value: 'Ada', new_value: 'Grace')

    assert_equal 'PcardInventory', edit.record_type
    assert_equal row.id, edit.record_id
    assert_equal [edit], RecordEdit.for_row(row).to_a
  end

  test 'capture attributes the edit to the actor' do
    edit = RecordEdit.capture(row: row, table_slug: 'pcard', column_name: 'first_name',
                              old_value: 'Ada', new_value: 'Grace',
                              actor: { id: '4242', name: 'Test User' })

    assert_equal '4242', edit.changed_by_id
    assert_equal 'Test User', edit.changed_by_name
  end

  test 'capture stamps created_at despite timestamps being off' do
    # record_timestamps is disabled (the row is never updated), so capture has
    # to set created_at itself — without it the audit trail has no ordering.
    edit = RecordEdit.capture(row: row, table_slug: 'pcard', column_name: 'first_name',
                              old_value: 'Ada', new_value: 'Grace')

    assert_not_nil edit.created_at
  end

  test 'capture tolerates a nil previous value' do
    edit = RecordEdit.capture(row: row, table_slug: 'pcard', column_name: 'mail_stop',
                              old_value: nil, new_value: 'MS-1')

    assert_nil edit.old_value
    assert_equal 'MS-1', edit.new_value
  end
end
