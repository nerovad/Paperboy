# frozen_string_literal: true

require 'test_helper'

module Forms
  # A member stepping out of one group subscription's mail: who is still
  # mailed, what the digest still covers, and what a required row overrides.
  class SubscriptionOptOutTest < ActiveSupport::TestCase
    CIR = 'CriticalInformationReporting'

    def subscription(**overrides)
      Forms::Subscription.create!({
        form_type: CIR,
        grantee_type: 'employee',
        employee_id: '900',
        notify_created: true,
        delivery_mode: Forms::Subscription::IMMEDIATE
      }.merge(overrides))
    end

    def group_subscription(group_id, **overrides)
      subscription(grantee_type: 'group', group_id: group_id, employee_id: nil, **overrides)
    end

    test 'an opted-out member drops out of a group subscription and nobody else does' do
      EmployeeGroup.insert_all([{ GroupID: 4250, EmployeeID: 7101 },
                                { GroupID: 4250, EmployeeID: 7102 }])
      row = group_subscription(4250)
      row.opt_outs.create!(employee_id: '7101')

      assert_equal ['7102'], Forms::Subscription.expand_recipients([row])
    end

    test 'an opt-out covers only the row it was made on' do
      EmployeeGroup.insert_all([{ GroupID: 4251, EmployeeID: 7103 },
                                { GroupID: 4252, EmployeeID: 7103 }])
      opted_out = group_subscription(4251)
      other_group = group_subscription(4252)
      opted_out.opt_outs.create!(employee_id: '7103')

      assert_equal ['7103'], Forms::Subscription.expand_recipients([opted_out, other_group])
    end

    test 'a personal subscription still mails somebody who opted out of the group row' do
      EmployeeGroup.insert_all([{ GroupID: 4253, EmployeeID: 7104 }])
      row = group_subscription(4253)
      row.opt_outs.create!(employee_id: '7104')
      personal = subscription(employee_id: '7104')

      assert_equal ['7104'], Forms::Subscription.expand_recipients([row, personal])
    end

    test 'a required subscription cannot be opted out of' do
      row = group_subscription(4254, required: true)

      assert_not row.opt_outs.build(employee_id: '7105').valid?
    end

    test 'a subscription made required ignores opt-outs recorded before' do
      EmployeeGroup.insert_all([{ GroupID: 4255, EmployeeID: 7106 }])
      row = group_subscription(4255)
      row.opt_outs.create!(employee_id: '7106')
      row.update!(required: true)

      assert_equal ['7106'], Forms::Subscription.expand_recipients([row])
    end

    test 'personal rows are never required' do
      assert_not subscription(required: true).required?
    end

    test 'for_subscriber leaves out group rows the employee opted out of, unless required' do
      EmployeeGroup.insert_all([{ GroupID: 4256, EmployeeID: 7107 }])
      opted_out = group_subscription(4256)
      required = group_subscription(4256, form_type: 'ProbationTransferRequest', required: true)
      opted_out.opt_outs.create!(employee_id: '7107')
      Forms::SubscriptionOptOut.insert_all([{ form_subscription_id: required.id, employee_id: '7107' }])
      personal = subscription(employee_id: '7107', form_type: 'SafetyReport')

      subscriptions = Forms::Subscription.for_subscriber('7107')

      assert_includes subscriptions, required
      assert_includes subscriptions, personal
      assert_not_includes subscriptions, opted_out
    end

    test 'removing a subscription removes its opt-outs' do
      row = group_subscription(4257)
      row.opt_outs.create!(employee_id: '7108')

      assert_difference -> { Forms::SubscriptionOptOut.count }, -1 do
        row.destroy
      end
    end
  end
end
