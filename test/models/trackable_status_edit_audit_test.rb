# frozen_string_literal: true

require 'test_helper'

# The edit trail TrackableStatus writes on update, and what it deliberately
# leaves out. Exercised through ProbationTransferRequest because it is the one
# TrackableStatus model with fixtures, and it routes by a direct assignee rather
# than routing steps, so no template lookup is involved.
class TrackableStatusEditAuditTest < ActiveSupport::TestCase
  setup do
    @record = probation_transfer_requests(:one)
  end

  def audit_rows = RecordEdit.for_row(@record).to_a

  test 'one audit row per column that actually moved' do
    assert_difference -> { audit_rows.size }, 2 do
      @record.update!(unit: 'UNIT-NEW', work_location: 'Somewhere else')
    end

    assert_equal %w[unit work_location], audit_rows.map(&:column_name).sort
  end

  test 'the row records what the value was and what it became' do
    @record.update!(unit: 'UNIT-NEW')
    row = audit_rows.find { |edit| edit.column_name == 'unit' }

    assert_equal 'MyString', row.old_value
    assert_equal 'UNIT-NEW', row.new_value
    assert_equal @record.class.name, row.record_type
  end

  test 'writing the same value again audits nothing' do
    assert_no_difference -> { audit_rows.size } do
      @record.update!(unit: @record.unit)
    end
  end

  test 'status is left to StatusChange rather than duplicated in the edit log' do
    assert_no_difference -> { audit_rows.size } do
      @record.update!(status: 'manager_approved')
    end
  end

  test 'a status change still records a StatusChange row' do
    assert_difference -> { @record.status_changes.count }, 1 do
      @record.update!(status: 'denied')
    end
  end

  test 'timestamps are not audited' do
    @record.update!(unit: 'UNIT-NEW')

    assert_not_includes audit_rows.map(&:column_name), 'updated_at'
  end

  test 'creating a record audits nothing' do
    # The edit trail is about changes to existing work; a new submission is the
    # 'created' subscription event instead.
    assert_no_difference -> { RecordEdit.count } do
      ProbationTransferRequest.create!(
        employee_id: 'aud-1', name: 'Audit Tester', email: 'audit@ventura.org',
        phone: '805-555-0100', agency: 'A', division: 'D', department: 'DE', unit: 'U',
        work_location: 'W', current_assignment_date: Date.current,
        desired_transfer_destination: 'Anywhere'
      )
    end
  end
end
