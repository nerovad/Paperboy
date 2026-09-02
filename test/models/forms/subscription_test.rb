# frozen_string_literal: true

require 'test_helper'

module Forms
  class SubscriptionTest < ActiveSupport::TestCase
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

    # --- validations ---

    test 'requires at least one event' do
      row = Forms::Subscription.new(form_type: CIR, grantee_type: 'employee', employee_id: '900')

      assert_not row.valid?
      assert_includes row.errors.full_messages.join, 'at least one event'
    end

    test 'a group subscription needs a group and an employee one needs an employee' do
      assert_not Forms::Subscription.new(form_type: CIR, grantee_type: 'group', notify_created: true).valid?
      assert_not Forms::Subscription.new(form_type: CIR, grantee_type: 'employee', notify_created: true).valid?
    end

    test 'rejects an unknown delivery mode' do
      row = Forms::Subscription.new(form_type: CIR, grantee_type: 'employee', employee_id: '900',
                                    notify_created: true, delivery_mode: 'hourly')

      assert_not row.valid?
    end

    test 'the same recipient cannot subscribe to one form twice' do
      subscription
      duplicate = Forms::Subscription.new(form_type: CIR, grantee_type: 'employee',
                                          employee_id: '900', notify_created: true)

      assert_not duplicate.valid?
    end

    # --- scopes ---

    test 'covering matches the form itself and any all-forms row' do
      exact = subscription
      everything = subscription(form_type: Forms::Subscription::ALL_FORMS)
      other = subscription(form_type: 'ProbationTransferRequest')

      covering = Forms::Subscription.covering(CIR)

      assert_includes covering, exact
      assert_includes covering, everything
      assert_not_includes covering, other
    end

    test 'for_event selects on that event only' do
      created = subscription(notify_created: true)
      edited = subscription(employee_id: '901', notify_created: false, notify_edited: true)

      assert_includes Forms::Subscription.for_event('created'), created
      assert_not_includes Forms::Subscription.for_event('created'), edited
      assert_includes Forms::Subscription.for_event('edited'), edited
    end

    test 'for_event matches nothing for an unknown event name' do
      subscription

      assert_empty Forms::Subscription.for_event('exploded')
      assert_empty Forms::Subscription.for_event(nil)
    end

    # --- recipients ---

    test 'recipient_ids_for returns employee grantees for the matching mode' do
      subscription(employee_id: '900')
      subscription(employee_id: '901', delivery_mode: Forms::Subscription::DAILY_DIGEST)

      immediate = Forms::Subscription.recipient_ids_for(
        form_type: CIR, event: 'created', delivery_mode: Forms::Subscription::IMMEDIATE
      )

      assert_equal ['900'], immediate
    end

    test 'recipient_ids_for expands a group to its members' do
      # insert_all skips EmployeeGroup's member_exists validation, which would
      # reach into GSABSS; the expansion under test only reads the two columns.
      EmployeeGroup.insert_all([{ GroupID: 4242, EmployeeID: 7001 },
                                { GroupID: 4242, EmployeeID: 7002 }])
      subscription(grantee_type: 'group', group_id: 4242, employee_id: nil)

      recipients = Forms::Subscription.recipient_ids_for(
        form_type: CIR, event: 'created', delivery_mode: Forms::Subscription::IMMEDIATE
      )

      assert_equal %w[7001 7002], recipients.sort
    end

    test 'recipient_ids_for ignores subscriptions for other events' do
      subscription(notify_created: false, notify_edited: true)

      assert_empty Forms::Subscription.recipient_ids_for(
        form_type: CIR, event: 'created', delivery_mode: Forms::Subscription::IMMEDIATE
      )
    end

    test 'expand_recipients dedupes somebody subscribed personally and through a group' do
      EmployeeGroup.insert_all([{ GroupID: 4243, EmployeeID: 7003 }])
      personal = subscription(employee_id: '7003')
      group = subscription(grantee_type: 'group', group_id: 4243, employee_id: nil)

      assert_equal ['7003'], Forms::Subscription.expand_recipients([personal, group])
    end

    # --- display ---

    test 'events and labels read back in a stable order' do
      row = subscription(notify_created: true, notify_edited: true, notify_status_changed: false)

      assert_equal %w[created edited], row.events
      assert_equal ['New submission', 'Field edited'], row.event_labels
    end

    test 'an all-forms row labels itself as such' do
      assert_predicate subscription(form_type: Forms::Subscription::ALL_FORMS), :all_forms?
      assert_equal Forms::Subscription::ALL_FORMS_LABEL,
                   subscription(form_type: Forms::Subscription::ALL_FORMS, employee_id: '999').form_label
    end
  end
end
