# frozen_string_literal: true

require 'test_helper'

# Reassignment used to work only for the three hand-written forms; every form
# the form builder generates keeps its assignee in approver_id and was left out.
# These cover the shared default that brought them in.
class ReassignableTest < ActiveSupport::TestCase
  # One representative form-builder form. It declares no assignee column of its
  # own — resolving it is the behaviour under test.
  def dynamic_form(**overrides)
    LeaveOfAbsenceForm.create!({ name: 'Away Tester', email: 'away@ventura.org',
                                 approver_id: '6001' }.merge(overrides))
  end

  test 'a form-builder form resolves approver_id without declaring it' do
    form = dynamic_form

    assert_equal 'approver_id', form.assignment_field_name
    assert_equal '6001', form.current_assignee_id
  end

  test 'a hand-written form keeps its own assignee column' do
    assert_equal 'supervisor_id', probation_transfer_requests(:one).assignment_field_name
  end

  test 'form-builder forms are reassignable' do
    %w[LeaveOfAbsenceForm PcardRequestForm BikeLockerForm IdBadgeRequestForm
       TeleworkLogForm WorkplaceViolenceForm CarpoolForm FleetVehicleGaragingForm
       FormRequestForm WorkScheduleOrLocationUpdateForm OshaReport].each do |name|
      model = name.constantize

      assert model.include?(Reassignable), "#{name} should be reassignable"
    end
  end

  test 'reassigning a form-builder form moves the approver and records history' do
    form = dynamic_form

    reassignment = Employee.stub(:find_by, Object.new) do
      form.reassign_to!(new_assignee_id: '6002', reassigned_by_id: '6003')
    end

    assert_equal '6002', form.reload.approver_id
    assert_equal 'approver_id', reassignment.assignment_field
    assert_equal '6001', reassignment.from_employee_id
    assert_equal '6002', reassignment.to_employee_id
  end

  test 'reassigning a form-builder form is audited' do
    form = dynamic_form

    assert_difference -> { RecordEdit.for_row(form).count }, 1 do
      Employee.stub(:find_by, Object.new) do
        form.reassign_to!(new_assignee_id: '6002', reassigned_by_id: '6003')
      end
    end

    edit = RecordEdit.for_row(form).newest_first.first

    assert_equal 'approver_id', edit.column_name
    assert_equal '6002', edit.new_value
  end

  test 'reassigning to the current holder is refused' do
    form = dynamic_form

    assert_raises(ArgumentError) do
      Employee.stub(:find_by, Object.new) do
        form.reassign_to!(new_assignee_id: '6001', reassigned_by_id: '6003')
      end
    end
  end
end
