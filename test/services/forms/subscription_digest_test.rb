# frozen_string_literal: true

require 'test_helper'

module Forms
  class SubscriptionDigestTest < ActiveSupport::TestCase
    PTR = 'ProbationTransferRequest'

    setup do
      @employee_id = '8100'
      @record = probation_transfer_requests(:one)
      @since = 1.day.ago
      @through = Time.current
    end

    def subscribe(**overrides)
      Forms::Subscription.create!({
        form_type: PTR,
        grantee_type: 'employee',
        employee_id: @employee_id,
        delivery_mode: Forms::Subscription::DAILY_DIGEST,
        notify_edited: true
      }.merge(overrides))
    end

    def digest = Forms::SubscriptionDigest.new(employee_id: @employee_id, since: @since, through: @through)

    def edit_row(created_at: Time.current, column: 'unit')
      RecordEdit.create!(record_type: PTR, record_id: @record.id, table_slug: 'probation',
                         column_name: column, old_value: 'a', new_value: 'b', created_at: created_at)
    end

    def status_row(from:, to: 'Approved', created_at: Time.current)
      StatusChange.create!(trackable: @record, from_status: from, to_status: to,
                           created_at: created_at, updated_at: created_at)
    end

    test 'a subscriber with no subscriptions has an empty digest' do
      edit_row

      assert_not_predicate digest, :any?
      assert_empty digest.edits
    end

    test 'edits inside the window are included and older ones are not' do
      subscribe
      recent = edit_row(created_at: 2.hours.ago)
      edit_row(created_at: 3.days.ago)

      assert_equal [recent.id], digest.edits.map(&:id)
      assert_predicate digest, :any?
    end

    test 'edits are only collected for forms followed for that event' do
      subscribe(notify_edited: false, notify_status_changed: true)
      edit_row

      assert_empty digest.edits
    end

    test 'status changes exclude a submission opening status' do
      subscribe(notify_edited: false, notify_status_changed: true)
      transition = status_row(from: 'In Progress')
      status_row(from: nil, to: 'In Progress')

      assert_equal [transition.id], digest.status_changes.map(&:id)
    end

    test 'immediate subscriptions are never part of a digest' do
      subscribe(delivery_mode: Forms::Subscription::IMMEDIATE)
      edit_row

      assert_empty digest.edits
      assert_not_predicate digest, :any?
    end

    test 'an all-forms subscription covers this form too' do
      subscribe(form_type: Forms::Subscription::ALL_FORMS)
      recent = edit_row

      assert_equal [recent.id], digest.edits.map(&:id)
    end

    test 'edits_by_record groups a submission changes together' do
      subscribe
      edit_row(column: 'unit')
      edit_row(column: 'agency')

      grouped = digest.edits_by_record

      assert_equal 1, grouped.size
      assert_equal 2, grouped[[PTR, @record.id]].size
    end

    test 'total_events counts every section' do
      subscribe(notify_created: false, notify_edited: true, notify_status_changed: true)
      edit_row
      status_row(from: 'In Progress')

      assert_equal 2, digest.total_events
    end
  end
end
