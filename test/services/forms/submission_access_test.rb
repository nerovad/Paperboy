# frozen_string_literal: true

require 'test_helper'

# Who may open one submission. Everyone the app already shows it to — and
# nobody holding only its link.
module Forms
  class SubmissionAccessTest < ActiveSupport::TestCase
    VIEWER = '7001'

    setup do
      @record = probation_transfer_requests(:one)
      @record.update_columns(employee_id: '5001', supervisor_id: '5002')
    end

    def viewable?(employee_id: VIEWER, **options)
      SubmissionAccess.stub(:supervisor_chain, ->(*) { [] }) do
        SubmissionAccess.viewable?(@record, employee_id: employee_id, **options)
      end
    end

    test 'someone with nothing but the link is refused' do
      assert_not viewable?
      assert_not viewable?(employee_id: nil)
    end

    test 'system admins may open anything' do
      assert viewable?(group_names: ['system_admins'])
    end

    test 'the submitter and the person it sits with may open it' do
      assert viewable?(employee_id: '5001')
      assert viewable?(employee_id: '5002')
    end

    test 'someone who already acted on it keeps sight of it' do
      StatusChange.create!(trackable: @record, from_status: 'in_progress', to_status: 'manager_approved',
                           changed_by_id: VIEWER)

      assert viewable?
    end

    test 'a Send a Copy To recipient may open it' do
      Forms::SubmissionCopy.create!(submission_type: @record.class.name, submission_id: @record.id,
                                    recipient_employee_id: VIEWER.to_i, delivered_via: 'submit')

      assert viewable?
    end

    test 'a supervisor above the submitter may open it' do
      chains = { '5001' => ['6001', VIEWER] }
      allowed = SubmissionAccess.stub(:supervisor_chain, ->(id) { chains.fetch(id, []) }) do
        SubmissionAccess.viewable?(@record, employee_id: VIEWER)
      end

      assert allowed
    end

    test 'an ACL visibility grant on the form opens it; one on another form does not' do
      Forms::VisibilityGrant.create!(form_type: 'SomeOtherForm', grantee_type: 'employee', employee_id: VIEWER)
      assert_not viewable?

      Forms::VisibilityGrant.create!(form_type: @record.class.name, grantee_type: 'employee', employee_id: VIEWER,
                                     applies_to: 'submissions')
      assert viewable?
    end

    test 'a grant reaches the viewer through their group' do
      group = Group.create!(Group_Name: "Access_Probe_#{SecureRandom.hex(3)}")
      Forms::VisibilityGrant.create!(form_type: Forms::VisibilityGrant::ALL_FORMS, grantee_type: 'group',
                                     group_id: group.GroupID)

      assert viewable?(group_ids: [group.GroupID])
    end

    test 'an ACL Edit or Change Status grant on the form includes seeing it' do
      assert viewable?(permission_keys: ["edit:#{@record.class.name}"])
      assert viewable?(permission_keys: ['change_status:*'])
      assert_not viewable?(permission_keys: ['edit:SomeOtherForm'])
    end

    test 'subscribing to a form does not open its submissions' do
      Forms::Subscription.create!(form_type: @record.class.name, grantee_type: 'employee', employee_id: VIEWER,
                                  notify_created: true, delivery_mode: 'immediate')

      assert_not viewable?
    end
  end
end
