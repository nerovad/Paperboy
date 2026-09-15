# frozen_string_literal: true

require 'test_helper'

# Records tables whose rows are the thing being tracked (P-Cards, Fleet
# Vehicles) audit the row being added and deleted as well as edited, and keep
# that history after the row is gone. Forms keep the old rule: their trail
# goes with them (see AuditableEditsTest).
class RecordLifecycleAuditTest < ActiveSupport::TestCase
  def history(row) = RecordEdit.where(record_type: 'PcardInventory', record_id: row.id)

  def create_card
    Current.set(user: { 'employee_id' => '5001', 'first_name' => 'Dana', 'last_name' => 'Reyes' }) do
      PcardInventory.create!(first_name: 'Ada', last_name: 'Lovelace', monthly_limit: 100)
    end
  end

  test 'adding a row records the values it started with' do
    card = create_card
    added = history(card).where(action: 'create').pluck(:column_name, :new_value).to_h

    assert_equal 'Ada', added['first_name']
    assert_equal 'Lovelace', added['last_name']
    assert_equal 'Dana Reyes', history(card).where(action: 'create').first.changed_by_name
    assert_not_includes added.keys, 'created_at'
    assert(history(card).where(action: 'create').all? { |edit| edit.old_value.nil? })
  end

  test 'editing the row afterwards is recorded as an update' do
    card = create_card
    card.update!(monthly_limit: 250)

    edit = history(card).updates.sole
    assert_equal 'monthly_limit', edit.column_name
    assert_equal '250.0', edit.new_value.to_f.to_s
  end

  test 'deleting the row records what it held and keeps its history' do
    card = create_card
    card.update!(first_name: 'Grace')
    card.destroy!

    assert_equal %w[create destroy update].sort, history(card).distinct.pluck(:action).sort
    assert_equal 'Grace', history(card).where(action: 'destroy', column_name: 'first_name').sole.old_value
  end

  test 'encrypted attributes are recorded as changed, never by value' do
    card = PcardInventory.new

    assert_equal AuditableEdits::REDACTED, card.send(:audited_value, 'card_number', '4111111111111111')
    assert_nil card.send(:audited_value, 'card_number', nil)
    assert_equal 'Ada', card.send(:audited_value, 'first_name', 'Ada')
  end

  test 'a form does not audit its lifecycle' do
    assert_not CreativeJobRequest.audits_record_lifecycle
    assert PcardInventory.audits_record_lifecycle
    assert FleetVehicle.audits_record_lifecycle
  end
end
