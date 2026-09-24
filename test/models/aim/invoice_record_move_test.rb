# frozen_string_literal: true

require 'test_helper'

module Aim
  # Recording where an invoice's files now are. The file has already moved by
  # the time this runs, so the row must follow -- a legal move as a
  # transition, anything else as a sync event that says why. Plan step 5.7b.
  class InvoiceRecordMoveTest < ActiveSupport::TestCase
    def invoice(state: 'action_needed', document_type: 'Invoice')
      Aim::Invoice.create!(batch_id: "4601_#{SecureRandom.hex(4)}", state: state,
                           document_type: document_type, actor: 'watcher')
    end

    test 'a move the pipeline makes is recorded as a transition by whoever made it' do
      record = invoice.record_move!('sql_queue', actor: 'reviewer@example.test')

      event = record.events.last
      assert_equal %w[transition action_needed sql_queue reviewer@example.test],
                   [event.action, event.from_state, event.to_state, event.actor]
    end

    test 'a move the pipeline does not make is followed and flagged' do
      record = invoice(state: 'sql_queue').record_move!('vendor_review', actor: 'reviewer@example.test')

      assert_equal 'vendor_review', record.reload.state
      event = record.events.last
      assert_equal %w[sync sql_queue vendor_review], [event.action, event.from_state, event.to_state]
      assert_equal 'moved outside the pipeline', event.note
    end

    test 'a move the type rule would refuse is followed, and the event names the rule' do
      record = invoice(document_type: 'Unknown').record_move!('user_approval', actor: 'reviewer@example.test')

      assert_equal 'user_approval', record.reload.state
      assert_match(/must be settled before an invoice reaches a user/, record.events.last.note)
    end

    test 'saying where it already is writes nothing' do
      record = invoice

      assert_no_difference -> { Aim::InvoiceEvent.count } do
        record.record_move!('action_needed', actor: 'reviewer@example.test')
      end
    end

    test 'a batch with no row yet is adopted where its files are' do
      record = Aim::Invoice.record_move!('4601.NEW', 'rejected', actor: 'reviewer@example.test')

      assert_equal 'rejected', record.state
      assert_equal 'reviewer@example.test', record.events.last.actor
    end

    test 'a claim is kept on the row and released from it' do
      record = invoice
      record.claim!('reviewer@example.test')

      assert_equal 'reviewer@example.test', record.reload.claimed_by
      assert_not_nil record.claimed_at

      record.release_claim!

      assert_nil record.reload.claimed_by
      assert_nil record.claimed_at
    end

    test 'a claim is not history' do
      record = invoice

      assert_no_difference -> { Aim::InvoiceEvent.count } do
        record.claim!('reviewer@example.test')
        record.release_claim!
      end
    end
  end
end
