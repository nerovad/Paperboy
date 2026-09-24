# frozen_string_literal: true

require 'test_helper'

module Aim
  class InvoiceEventTest < ActiveSupport::TestCase
    def create_invoice(state: 'received', actor: 'watcher')
      Aim::Invoice.create!(batch_id: "4601_#{SecureRandom.hex(4)}", state: state, actor: actor)
    end

    test 'reads its table from the aim schema' do
      assert_equal 'aim.invoice_events', Aim::InvoiceEvent.table_name
    end

    test 'creating an invoice records its first state' do
      invoice = create_invoice

      assert_equal 1, invoice.events.count
      event = invoice.events.first
      assert_equal ['transition', nil, 'received', 'watcher'],
                   [event.action, event.from_state, event.to_state, event.actor]
    end

    test 'every change of state writes exactly one event' do
      invoice = create_invoice
      invoice.update!(state: 'extracting', actor: 'aim_worker')
      invoice.update!(state: 'needs_review', actor: 'aim_worker')

      transitions = invoice.events.reload.map { [_1.from_state, _1.to_state] }

      assert_equal [[nil, 'received'], %w[received extracting], %w[extracting needs_review]], transitions
      assert_equal %w[watcher aim_worker aim_worker], invoice.events.map(&:actor)
    end

    test 'a save that leaves the state alone writes nothing' do
      invoice = create_invoice

      assert_no_difference -> { Aim::InvoiceEvent.count } do
        invoice.update!(vendor_name: 'AT&T MOBILITY')
      end
    end

    test 'a change of state must say who made it' do
      invoice = create_invoice

      assert_not invoice.update(state: 'extracting')
      assert_includes invoice.errors[:actor], "can't be blank"
      assert_equal 1, invoice.events.count
    end

    test 'the actor is not carried over to the next change' do
      invoice = create_invoice
      invoice.update!(state: 'extracting', actor: 'someone@example.test')

      assert_nil invoice.actor
      assert_not invoice.update(state: 'failed')
    end

    test 'an event that fails to write takes the state change with it' do
      invoice = create_invoice
      failing = ->(*) { raise ActiveRecord::RecordInvalid }

      invoice.events.stub(:create!, failing) do
        assert_raises(ActiveRecord::RecordInvalid) { invoice.update!(state: 'extracting', actor: 'x') }
      end
      assert_equal 'received', invoice.reload.state
      assert_equal 1, invoice.events.count
    end

    test 'history cannot be edited or deleted' do
      event = create_invoice.events.first

      assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(actor: 'someone else') }
      assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy }
    end

    test 'an invoice with history cannot be deleted' do
      invoice = create_invoice

      assert_raises(ActiveRecord::DeleteRestrictionError) { invoice.destroy }
    end

    test 'an event belongs to an invoice' do
      event = Aim::InvoiceEvent.new(action: 'transition', actor: 'x')

      assert_not event.valid?
      assert_includes event.errors[:invoice], 'must exist'
    end
  end
end
