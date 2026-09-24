# frozen_string_literal: true

require 'test_helper'

module Aim
  # AIM's work, as Paperboy's inbox sees it: rows in the queues a person
  # works, claimed or not. AIM v2.
  class WorkProviderTest < ActiveSupport::TestCase
    VIEWER = { email: 'reviewer@example.gov', employee_id: '42', applications: ['aim'] }.freeze

    def invoice(batch_id, state: 'needs_review', **attributes)
      Aim::Invoice.create!(batch_id: batch_id, state: state, actor: 'aim_worker', **attributes)
    end

    test 'publishes unclaimed work to authorized AIM viewers' do
      invoice('INV-123', invoice_number: '123', vendor_name: 'ACME')
      invoice('INV-999', state: 'exported')

      items = Aim::WorkProvider.new.inbox_items(viewer: VIEWER, filters: { queue: 'needs_review' })

      assert_equal ['aim:invoice:needs_review:INV-123'], items.map(&:key)
      assert_equal %i[open claim], items.first.actions
      assert_equal '123', items.first.reference
      assert_equal '/aim/invoices/INV-123?queue=needs_review', items.first.path
    end

    test 'hides work claimed by another reviewer and keeps the viewer\'s own' do
      invoice('INV-456', claimed_by: 'other@example.gov', claimed_at: Time.current)
      invoice('INV-457', claimed_by: 'reviewer@example.gov', claimed_at: Time.current)

      items = Aim::WorkProvider.new.inbox_items(viewer: VIEWER)

      assert_equal ['aim:invoice:needs_review:INV-457'], items.map(&:key)
      assert_equal %i[open release], items.first.actions
    end

    test 'lists every work queue and no finished invoice' do
      invoice('A', state: 'needs_split')
      invoice('B', state: 'ready_for_approval', document_type: 'Invoice')
      invoice('C', state: 'failed')
      invoice('D', state: 'deleted')

      items = Aim::WorkProvider.new.records(viewer: VIEWER)

      assert_equal %w[A B C], items.map(&:source_id).sort
      assert_equal :in_review, items.find { |item| item.source_id == 'B' }.status_category
    end

    test 'a viewer without the app sees nothing' do
      invoice('INV-1')

      assert_empty Aim::WorkProvider.new.inbox_items(viewer: { email: 'x', applications: [] })
    end
  end
end
