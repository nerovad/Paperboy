# frozen_string_literal: true

require 'test_helper'

module Aim
  class InvoiceEventTest < ActiveSupport::TestCase
    def create_invoice(state: 'ai_queue', actor: 'watcher')
      Aim::Invoice.create!(batch_id: "4601_#{SecureRandom.hex(4)}", state: state, actor: actor)
    end

    test 'reads its table from the aim schema' do
      assert_equal 'aim.invoice_events', Aim::InvoiceEvent.table_name
    end

    test 'creating an invoice records its first state' do
      invoice = create_invoice

      assert_equal 1, invoice.events.count
      event = invoice.events.first
      assert_equal ['transition', nil, 'ai_queue', 'watcher'],
                   [event.action, event.from_state, event.to_state, event.actor]
    end

    test 'every change of state writes exactly one event' do
      invoice = create_invoice
      invoice.update!(state: 'sql_queue', actor: '01_ai_extraction_worker')
      invoice.update!(state: 'user_approval', actor: '02_sql_worker')

      transitions = invoice.events.reload.map { [_1.from_state, _1.to_state] }

      assert_equal [[nil, 'ai_queue'], %w[ai_queue sql_queue], %w[sql_queue user_approval]], transitions
      assert_equal %w[watcher 01_ai_extraction_worker 02_sql_worker], invoice.events.map(&:actor)
    end

    test 'a save that leaves the state alone writes nothing' do
      invoice = create_invoice

      assert_no_difference -> { Aim::InvoiceEvent.count } do
        invoice.update!(vendor_name: 'AT&T MOBILITY')
      end
    end

    test 'a change of state must say who made it' do
      invoice = create_invoice

      assert_not invoice.update(state: 'sql_queue')
      assert_includes invoice.errors[:actor], "can't be blank"
      assert_equal 1, invoice.events.count
    end

    test 'the actor is not carried over to the next change' do
      invoice = create_invoice
      invoice.update!(state: 'sql_queue', actor: 'someone@example.test')

      assert_nil invoice.actor
      assert_not invoice.update(state: 'user_approval')
    end

    test 'an event that fails to write takes the state change with it' do
      invoice = create_invoice
      failing = ->(*) { raise ActiveRecord::RecordInvalid }

      invoice.events.stub(:create!, failing) do
        assert_raises(ActiveRecord::RecordInvalid) { invoice.update!(state: 'sql_queue', actor: 'x') }
      end
      assert_equal 'ai_queue', invoice.reload.state
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
