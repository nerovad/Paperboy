# frozen_string_literal: true

require 'test_helper'

module Aim
  # AIM's work, as Paperboy's inbox sees it. A person's inbox holds what their
  # own AIM queues hold -- My Queue and the Shared Queues they pick up from --
  # and AIM Admins' also the Pipeline's Action Needed and Failed. AIM v2.
  class WorkProviderTest < ActiveSupport::TestCase
    VIEWER = { email: 'reviewer@example.gov', employee_id: '42', applications: ['aim'] }.freeze

    def invoice(batch_id, state: 'needs_review', **attributes)
      attributes[:document_type] ||= 'Invoice' if state == 'ready_for_approval'
      Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'aim_worker', **attributes)
    end

    def mine(batch_id, **attributes)
      invoice(batch_id, state: 'ready_for_approval', assigned_employee_id: 42, assigned_to: 'Rey Viewer',
                        assignment_source: 'upload', **attributes)
    end

    def inbox(viewer = VIEWER, filters: {}, admins: [])
      Group.stub(:employee_ids_named, admins) { Aim::WorkProvider.new.inbox_items(viewer: viewer, filters: filters) }
    end

    test 'the viewer\'s own ready invoices are in their inbox' do
      mine('INV-123', invoice_number: '123', vendor_name: 'ACME')
      invoice('INV-124', state: 'ready_for_approval', assigned_employee_id: 7, assigned_to: 'Someone Else',
                         assignment_source: 'upload')

      items = inbox

      assert_equal ['aim:invoice:ready_for_approval:INV-123'], items.map(&:key)
      assert_equal %i[open claim], items.first.actions
      assert_equal '123', items.first.reference
      assert_equal '/aim/invoices/INV-123?queue=ready_for_approval', items.first.path
    end

    test 'shared queues count only in the budget units the viewer picks up from' do
      Aim::UserBudgetUnit.create!(employee_id: 42, budget_unit: '4601', shared_queue: true)
      invoice('S-1', state: 'ready_for_approval', budget_unit: '4601')
      invoice('S-2', state: 'ready_for_approval', budget_unit: '4702')

      assert_equal ['S-1'], inbox.map(&:source_id)
    end

    test 'nobody else\'s unclaimed invoices reach a user\'s inbox' do
      invoice('A', state: 'needs_review')
      invoice('B', state: 'failed')
      invoice('C', state: 'ready_for_approval', budget_unit: '4601')

      assert_empty inbox
    end

    test 'AIM Admins also get Action Needed and Failed, less what someone else has open' do
      invoice('A', state: 'needs_split')
      invoice('B', state: 'failed')
      invoice('C', claimed_by: 'other@example.gov', claimed_at: Time.current)
      invoice('D', claimed_by: 'reviewer@example.gov', claimed_at: Time.current)
      invoice('E', state: 'deleted')

      items = inbox(admins: [42])

      assert_equal %w[A B D], items.map(&:source_id).sort
      assert_equal %i[open release], items.find { |item| item.source_id == 'D' }.actions
    end

    test 'a queue filter narrows the inbox' do
      mine('R-1')
      invoice('N-1')

      assert_equal ['N-1'], inbox(filters: { queue: 'needs_review' }, admins: [42]).map(&:source_id)
    end

    test 'lists every work queue and no finished invoice' do
      invoice('A', state: 'needs_split')
      invoice('B', state: 'ready_for_approval')
      invoice('C', state: 'failed')
      invoice('D', state: 'deleted')

      items = Aim::WorkProvider.new.records(viewer: VIEWER)

      assert_equal %w[A B C], items.map(&:source_id).sort
      assert_equal :in_review, items.find { |item| item.source_id == 'B' }.status_category
    end

    test 'a viewer without the app, or without an employee id, sees nothing' do
      mine('INV-1')

      assert_empty inbox({ email: 'x', employee_id: '42', applications: [] })
      assert_empty inbox({ email: 'x', applications: ['aim'] })
    end
  end
end
