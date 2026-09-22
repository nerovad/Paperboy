# frozen_string_literal: true

require 'test_helper'

module Aim
  # The whole transition table, in both directions: every move the pipeline
  # makes is allowed, and every one of the several hundred it does not make is
  # refused. Plan step 5.4.
  # rubocop:disable Metrics/ClassLength
  class InvoiceStateMachineTest < ActiveSupport::TestCase
    def create_invoice(state:, document_type: 'Invoice')
      Aim::Invoice.create!(batch_id: "4601_#{SecureRandom.hex(4)}", state: state,
                           document_type: document_type, actor: 'watcher')
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

    test 'a finished invoice goes nowhere' do
      Aim::Invoice::TERMINAL_STATES.each do |state|
        assert_empty Aim::Invoice::TRANSITIONS.fetch(state), "#{state} should be an end"
      end
    end

    test 'no state moves to itself' do
      Aim::Invoice::TRANSITIONS.each do |from, destinations|
        assert_not_includes destinations, from, "#{from} moves to itself"
      end
    end

    test 'every state except the entry points is reachable' do
      reached = Aim::Invoice::TRANSITIONS.values.flatten.uniq
      unreachable = Aim::Invoice::STATES - reached - %w[ai_queue]

      assert_empty unreachable, "nothing moves to: #{unreachable.join(', ')}"
    end

    # ---------------------------------------------------------------
    # Every allowed move, and every refused one
    # ---------------------------------------------------------------

    test 'every move the pipeline makes is allowed' do
      Aim::Invoice::TRANSITIONS.each do |from, destinations|
        destinations.each do |to|
          invoice = create_invoice(state: from)
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

      assert_operator refused, :>, 200, 'the table should refuse far more moves than it allows'
    end

    test 'the refusal says where the invoice can actually go' do
      invoice = create_invoice(state: 'sql_queue')

      error = assert_raises(Aim::Invoice::IllegalTransition) { invoice.transition_to!('deleted', actor: 'tester') }

      assert_match(/cannot move from sql_queue to deleted/, error.message)
      assert_match(/archived, sql_failed, action_needed/, error.message)
    end

    test 'a finished invoice says so in the refusal' do
      invoice = create_invoice(state: 'archived')

      error = assert_raises(Aim::Invoice::IllegalTransition) { invoice.transition_to!('sql_queue', actor: 'tester') }

      assert_match(/nowhere, it is finished/, error.message)
    end

    # ---------------------------------------------------------------
    # The rules hold however the move is attempted
    # ---------------------------------------------------------------

    test 'a bare update cannot make a move transition_to! would refuse' do
      invoice = create_invoice(state: 'sql_queue')

      assert_not invoice.update(state: 'deleted', actor: 'tester')
      assert_includes invoice.errors[:state], 'cannot move from sql_queue to deleted'
      assert_equal 'sql_queue', invoice.reload.state
    end

    test 'a refused move writes no history' do
      invoice = create_invoice(state: 'sql_queue')

      assert_no_difference -> { Aim::InvoiceEvent.count } do
        assert_raises(Aim::Invoice::IllegalTransition) { invoice.transition_to!('deleted', actor: 'tester') }
        invoice.update(state: 'deleted', actor: 'tester')
      end
    end

    test 'an allowed move writes one event naming who made it' do
      invoice = create_invoice(state: 'action_needed')

      assert_difference -> { Aim::InvoiceEvent.count }, 1 do
        invoice.transition_to!('user_approval', actor: 'reviewer@example.test', note: 'vendor corrected')
      end

      event = invoice.events.last
      assert_equal %w[action_needed user_approval], [event.from_state, event.to_state]
      assert_equal 'reviewer@example.test', event.actor
      assert_equal 'vendor corrected', event.note
    end

    test 'a note belongs to its own move and no later one' do
      invoice = create_invoice(state: 'action_needed')
      invoice.transition_to!('user_approval', actor: 'reviewer@example.test', note: 'vendor corrected')
      invoice.transition_to!('sql_queue', actor: 'reviewer@example.test')

      assert_nil invoice.events.last.note
    end

    test 'a move must name who made it' do
      invoice = create_invoice(state: 'action_needed')

      assert_not invoice.update(state: 'user_approval')
      assert_includes invoice.errors[:actor], "can't be blank"
    end

    # ---------------------------------------------------------------
    # An invoice nobody has typed does not reach a user
    # ---------------------------------------------------------------

    test 'an untyped invoice cannot reach a user queue' do
      invoice = create_invoice(state: 'action_needed', document_type: 'Unknown')

      error = assert_raises(ActiveRecord::RecordInvalid) do
        invoice.transition_to!('user_approval', actor: 'reviewer@example.test')
      end

      assert_match(/must be settled before an invoice reaches a user/, error.message)
      assert_equal 'action_needed', invoice.reload.state
    end

    test 'an invoice with no type at all cannot reach a user queue either' do
      invoice = create_invoice(state: 'action_needed', document_type: nil)

      assert_raises(ActiveRecord::RecordInvalid) do
        invoice.transition_to!('user_approval', actor: 'reviewer@example.test')
      end
    end

    test 'settling the type in QA review lets the invoice through' do
      invoice = create_invoice(state: 'action_needed', document_type: 'Unknown')
      invoice.update!(document_type: 'Credit')
      invoice.transition_to!('user_approval', actor: 'reviewer@example.test')

      assert_equal 'user_approval', invoice.reload.state
    end

    test 'an unknown type does not block the rest of the pipeline' do
      invoice = create_invoice(state: 'ai_queue', document_type: 'Unknown')
      invoice.transition_to!('action_needed', actor: '01_ai_extraction_worker')

      assert_equal 'action_needed', invoice.reload.state
    end

    test 'a document type off the list is refused' do
      invoice = Aim::Invoice.new(batch_id: 'x', state: 'ai_queue', actor: 'watcher', document_type: 'Receipt')

      assert_not invoice.valid?
      assert_includes invoice.errors[:document_type], 'is not included in the list'
    end

    # ---------------------------------------------------------------
    # Small helpers the screens will use
    # ---------------------------------------------------------------

    test 'terminal? knows when an invoice is finished' do
      assert_predicate create_invoice(state: 'archived'), :terminal?
      assert_not_predicate create_invoice(state: 'sql_queue'), :terminal?
    end

    test 'next_states lists where this invoice can go' do
      assert_equal %w[archived sql_failed action_needed], create_invoice(state: 'sql_queue').next_states
    end
  end
  # rubocop:enable Metrics/ClassLength
end
