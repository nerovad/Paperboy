# frozen_string_literal: true

require 'test_helper'

# The edit trail TrackableStatus writes on update, and what it deliberately
# leaves out. Exercised through ProbationTransferRequest because it is the one
# TrackableStatus model with fixtures, and it routes by a direct assignee rather
# than routing steps, so no template lookup is involved.
class TrackableStatusEditAuditTest < ActiveSupport::TestCase
  # ActiveJob::TestHelper comes with this and swaps the sidekiq adapter for the
  # test one, so the mail a subscription triggers can be asserted on.
  include ActionMailer::TestHelper

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

  # --- reassignment ---
  #
  # Reassignable#reassign_to! writes the assignee with update_column, so none of
  # the callbacks above run for it. These cover the explicit audit that
  # replaces them.

  def reassign(to:, from: '5001')
    @record.update_column(:supervisor_id, from)
    # The real lookup is a GSABSS read the suite does not make; any truthy value
    # gets past reassign_to!'s "does this employee exist" guard.
    Employee.stub(:find_by, Object.new) do
      @record.reassign_to!(new_assignee_id: to, reassigned_by_id: '5003')
    end
  end

  test 'a reassignment is audited even though it bypasses callbacks' do
    assert_difference -> { audit_rows.size }, 1 do
      reassign(to: '5002')
    end

    row = audit_rows.find { |edit| edit.column_name == 'supervisor_id' }

    assert_equal '5001', row.old_value
    assert_equal '5002', row.new_value
  end

  test 'a reassignment still records its own history row' do
    assert_difference -> { @record.task_reassignments.count }, 1 do
      reassign(to: '5002')
    end
  end

  test 'a reassignment mails an immediate subscriber following edits' do
    Forms::Subscription.create!(form_type: 'ProbationTransferRequest', grantee_type: 'employee',
                                employee_id: '5009', notify_edited: true,
                                delivery_mode: Forms::Subscription::IMMEDIATE)

    assert_enqueued_emails 1 do
      reassign(to: '5002')
    end
  end

  test 'a reassignment mails nobody when no one follows edits' do
    Forms::Subscription.create!(form_type: 'ProbationTransferRequest', grantee_type: 'employee',
                                employee_id: '5009', notify_status_changed: true,
                                delivery_mode: Forms::Subscription::IMMEDIATE)

    assert_no_enqueued_emails do
      reassign(to: '5002')
    end
  end
end
