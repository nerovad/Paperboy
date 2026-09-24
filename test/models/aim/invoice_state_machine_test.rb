# frozen_string_literal: true

require 'test_helper'

module Aim
  # The whole transition table, in both directions: every move the pipeline
  # makes is allowed, and every one of the many it does not make is refused.
  # AIM v2: the row is the truth, so there is no "sync" any more.
  # rubocop:disable-next Metrics/ClassLength
  class InvoiceStateMachineTest < ActiveSupport::TestCase
    def create_invoice(state:, document_type: 'Invoice', **attributes)
      Aim::Invoice.create!(batch_id: "4601_#{SecureRandom.hex(4)}", state: state,
                           document_type: document_type, actor: 'intake', **attributes)
    end

    # ---------------------------------------------------------------
    # The table itself
    # ---------------------------------------------------------------

    test 'every state declares where it can go' do
      assert_equal Aim::Invoice::STATES.sort, Aim::Invoice::TRANSITIONS.keys.sort
    end

    test 'every destination is a state' do
      Aim::Invoice::TRANSITIONS.each do |from, destinations|
        unknown = destinations - Aim::Invoice::STATES
        assert_empty unknown, "#{from} points at #{unknown.join(', ')}"
      end
    end

    test 'a finished invoice goes nowhere, except that a rejected or deleted one can be restored' do
      (Aim::Invoice::TERMINAL_STATES - %w[rejected deleted]).each do |state|
        assert_empty Aim::Invoice::TRANSITIONS.fetch(state), "#{state} should be an end"
      end
      %w[rejected deleted].each do |state|
        assert_equal %w[needs_review ready_for_approval], Aim::Invoice::TRANSITIONS.fetch(state)
      end
    end

    test 'no state moves to itself' do
      Aim::Invoice::TRANSITIONS.each do |from, destinations|
        assert_not_includes destinations, from, "#{from} moves to itself"
      end
    end

    test 'every state except the entry point is reachable' do
      reached = Aim::Invoice::TRANSITIONS.values.flatten.uniq
      unreachable = Aim::Invoice::STATES - reached - %w[received]

      assert_empty unreachable, "nothing moves to: #{unreachable.join(', ')}"
    end

    test 'every state belongs to exactly one queue' do
      Aim::Invoice::STATES.each do |state|
        queues = Aim::Invoice::QUEUES.select { |_, queue| queue[:states].include?(state) }.keys
        assert_equal 1, queues.size, "#{state} is in #{queues.inspect}"
      end
    end

    # ---------------------------------------------------------------
    # Every allowed move, and every refused one
    # ---------------------------------------------------------------

    test 'every move the pipeline makes is allowed' do
      Aim::Invoice::TRANSITIONS.each do |from, destinations|
        destinations.each do |to|
          invoice = create_invoice(state: from, vendor_name: 'ACME', invoice_number: 'INV-1')
          invoice.transition_to!(to, actor: 'tester')

          assert_equal to, invoice.reload.state, "#{from} -> #{to} was refused"
        end
      end
    end

    test 'every move the pipeline does not make is refused' do
      refused = 0

      Aim::Invoice::TRANSITIONS.each do |from, destinations|
        (Aim::Invoice::STATES - destinations).each do |to|
          invoice = create_invoice(state: from)

          assert_raises(Aim::Invoice::IllegalTransition, "#{from} -> #{to} was allowed") do
            invoice.transition_to!(to, actor: 'tester')
          end
          assert_equal from, invoice.reload.state
          refused += 1
        end
      end

      assert_operator refused, :>, 100, 'the table should refuse far more moves than it allows'
    end

    test 'the refusal says where the invoice can actually go' do
      invoice = create_invoice(state: 'approved')

      error = assert_raises(Aim::Invoice::IllegalTransition) { invoice.transition_to!('deleted', actor: 'tester') }

      assert_match(/cannot move from approved to deleted/, error.message)
      assert_match(/exporting, needs_review/, error.message)
    end

    test 'a finished invoice says so in the refusal' do
      invoice = create_invoice(state: 'exported')

      error = assert_raises(Aim::Invoice::IllegalTransition) { invoice.transition_to!('approved', actor: 'tester') }

      assert_match(/nowhere, it is finished/, error.message)
    end

    # ---------------------------------------------------------------
    # The rules hold however the move is attempted
    # ---------------------------------------------------------------

    test 'a bare update cannot make a move transition_to! would refuse' do
      invoice = create_invoice(state: 'approved')

      assert_not invoice.update(state: 'deleted', actor: 'tester')
      assert_includes invoice.errors[:state], 'cannot move from approved to deleted'
      assert_equal 'approved', invoice.reload.state
    end

    test 'a refused move writes no history' do
      invoice = create_invoice(state: 'approved')

      assert_no_difference -> { Aim::InvoiceEvent.count } do
        assert_raises(Aim::Invoice::IllegalTransition) { invoice.transition_to!('deleted', actor: 'tester') }
        invoice.update(state: 'deleted', actor: 'tester')
      end
    end

    test 'an allowed move writes one event naming who made it' do
      invoice = create_invoice(state: 'needs_review')

      assert_difference -> { Aim::InvoiceEvent.count }, 1 do
        invoice.transition_to!('ready_for_approval', actor: 'reviewer@example.test', note: 'vendor corrected')
      end

      event = invoice.events.last
      assert_equal %w[needs_review ready_for_approval], [event.from_state, event.to_state]
      assert_equal 'reviewer@example.test', event.actor
      assert_equal 'vendor corrected', event.note
    end

    test 'a note belongs to its own move and no later one' do
      invoice = create_invoice(state: 'needs_review')
      invoice.transition_to!('ready_for_approval', actor: 'reviewer@example.test', note: 'vendor corrected')
      invoice.transition_to!('approved', actor: 'reviewer@example.test')

      assert_nil invoice.events.last.note
    end

    test 'a move must name who made it' do
      invoice = create_invoice(state: 'needs_review')

      assert_not invoice.update(state: 'ready_for_approval')
      assert_includes invoice.errors[:actor], "can't be blank"
    end

    # ---------------------------------------------------------------
    # Commands: what the screens ask the worker for
    # ---------------------------------------------------------------

    test 'requesting extraction sets received and the extract command in one save' do
      invoice = create_invoice(state: 'needs_review', review_reason: 'missing_fields', review_note: 'no total',
                               lease_owner: 'worker-1', lease_until: 1.hour.from_now)

      invoice.request_extract!(actor: 'reviewer@example.test')

      invoice.reload
      assert_equal %w[received extract], [invoice.state, invoice.command]
      assert_nil invoice.review_reason
      assert_nil invoice.lease_owner
      assert_predicate invoice, :split_check
    end

    test 'process as one invoice turns the split check off' do
      invoice = create_invoice(state: 'needs_split')

      invoice.request_extract!(actor: 'reviewer@example.test', split_check: false)

      assert_not invoice.reload.split_check
      assert_equal 'extract', invoice.command
    end

    test 'requesting export sets approved and the export command' do
      invoice = create_invoice(state: 'ready_for_approval')

      invoice.request_export!(actor: 'owner@example.test')

      assert_equal %w[approved export], [invoice.reload.state, invoice.command]
    end

    test 'a split is approved in place, with the manifest and a command event' do
      invoice = create_invoice(state: 'needs_split')
      manifest = { 'invoices' => [{ 'pages' => [1] }, { 'pages' => [2] }] }

      invoice.request_split!(manifest, actor: 'reviewer@example.test')

      invoice.reload
      assert_equal 'needs_split', invoice.state
      assert_equal 'split', invoice.command
      assert_equal manifest, invoice.manifest_data
      assert_equal 'command', invoice.events.last.action
    end

    test 'a command must be one the worker knows' do
      assert_not create_invoice(state: 'received').update(command: 'dance')
      assert create_invoice(state: 'received').update(command: nil)
    end

    test 'a review reason must be one on the list' do
      assert_not create_invoice(state: 'needs_review').update(review_reason: 'bored')
    end

    # ---------------------------------------------------------------
    # An invoice nobody has typed does not reach a user
    # ---------------------------------------------------------------

    test 'an untyped invoice cannot reach a user' do
      invoice = create_invoice(state: 'needs_review', document_type: 'Unknown')

      error = assert_raises(ActiveRecord::RecordInvalid) do
        invoice.transition_to!('ready_for_approval', actor: 'reviewer@example.test')
      end

      assert_match(/must be settled before an invoice reaches a user/, error.message)
      assert_equal 'needs_review', invoice.reload.state
    end

    test 'settling the type lets the invoice through' do
      invoice = create_invoice(state: 'needs_review', document_type: 'Unknown')
      invoice.update!(document_type: 'Credit')
      invoice.transition_to!('ready_for_approval', actor: 'reviewer@example.test')

      assert_equal 'ready_for_approval', invoice.reload.state
    end

    test 'an unknown type does not block the worker' do
      invoice = create_invoice(state: 'extracting', document_type: 'Unknown')
      invoice.transition_to!('needs_review', actor: 'aim_worker')

      assert_equal 'needs_review', invoice.reload.state
    end

    test 'ready_for_a_user? names what is missing' do
      invoice = create_invoice(state: 'needs_review', document_type: 'Unknown')

      assert_not invoice.ready_for_a_user?
      assert_equal ['a document type', 'a vendor name', 'an invoice number'], invoice.missing_for_a_user

      invoice.update!(document_type: 'Invoice', vendor_name: 'ACME', invoice_number: 'INV-1')
      assert_predicate invoice, :ready_for_a_user?
    end

    # ---------------------------------------------------------------
    # Small helpers the screens use
    # ---------------------------------------------------------------

    test 'terminal? knows when an invoice is finished' do
      assert_predicate create_invoice(state: 'exported'), :terminal?
      assert_not_predicate create_invoice(state: 'approved'), :terminal?
    end

    test 'next_states lists where this invoice can go' do
      assert_equal %w[exporting needs_review], create_invoice(state: 'approved').next_states
    end

    test 'queue_counts counts every queue, empty ones included' do
      create_invoice(state: 'needs_review')
      create_invoice(state: 'approved')
      create_invoice(state: 'exporting')

      counts = Aim::Invoice.queue_counts

      assert_equal 1, counts['needs_review']
      assert_equal 2, counts['in_flight']
      assert_equal 0, counts['deleted']
      assert_equal Aim::Invoice::QUEUES.keys, counts.keys
    end

    test 'an invoice knows its queue' do
      assert_equal 'in_flight', create_invoice(state: 'exporting').queue
    end
  end
end
