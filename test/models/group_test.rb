# frozen_string_literal: true

require 'test_helper'

class GroupTest < ActiveSupport::TestCase
  test 'employee ids of the groups with these names, each once' do
    clerks = Group.create!(Group_Name: 'test_clerks')
    staff = Group.create!(Group_Name: 'test_staff')
    other = Group.create!(Group_Name: 'test_other')
    EmployeeGroup.insert_all([{ GroupID: clerks.GroupID, EmployeeID: 7101 },
                              { GroupID: staff.GroupID, EmployeeID: 7101 },
                              { GroupID: staff.GroupID, EmployeeID: 7102 },
                              { GroupID: other.GroupID, EmployeeID: 7103 }])

    assert_equal [7101, 7102], Group.employee_ids_named('test_clerks', 'TEST_STAFF').sort
    assert_equal [7101, 7102], Group.employee_ids_named(%w[test_clerks test_staff]).sort
    assert_equal [], Group.employee_ids_named('no_such_group')
    assert_equal [7103], EmployeeGroup.member_ids(other.GroupID)
  end

  test 'the privileged group name is shared with ACL' do
    assert_equal 'system_admins', Group::PRIVILEGED_NAME
    assert_equal Group::PRIVILEGED_NAME, AclController::PRIVILEGED_GROUP_NAME
  end
end
