# frozen_string_literal: true

require 'test_helper'

module Aim
  # Waiting for AI (#192): hold an invoice from the AI, release it, or take it
  # from the AI -- only from a worker that gives it up (its lease name ends
  # in +stop); every move a person makes takes the worker's command and lease.
  class InvoiceAiControlTest < ActiveSupport::TestCase
    def invoice(state: 'received', command: 'extract', owner: nil, **attributes)
      Aim::Invoice.create!(batch_id: "4601_#{SecureRandom.hex(4)}", state: state, command: command, actor: 'intake',
                           lease_owner: owner, lease_until: (owner ? 10.minutes.from_now : nil), **attributes)
    end

    test 'a hold leaves it waiting with no command, so the worker never takes it, until released' do
      row = invoice

      row.hold_ai!(actor: 'staff@example.test', reason: 'vendor sends a corrected copy')

      assert_equal ['received', nil], [row.reload.state, row.command]
      assert row.on_hold?
      assert_equal "#{Aim::InvoiceAiControl::HOLD_NOTE}: vendor sends a corrected copy", row.events.last.note

      row.release_hold!(actor: 'staff@example.test')
      assert_equal 'extract', row.reload.command
      assert_not row.on_hold?
      assert_raises(Aim::Invoice::IllegalTransition) { row.release_hold!(actor: 'x') }
    end

    test 'holding one the AI is reading takes it from the worker' do
      row = invoice(state: 'extracting', owner: 'SCAN02:aim_worker+stop')

      row.hold_ai!(actor: 'staff@example.test')

      assert_equal ['received', nil, nil, nil], [row.state, row.command, row.lease_owner, row.lease_until]
    end

    test 'nothing is taken from a worker that cannot be stopped while it reads' do
      row = invoice(state: 'extracting', owner: 'SCAN02:aim_worker')

      assert_not row.ai_stoppable?
      assert_not row.sendable?
      %i[hold_ai! restart_ai! skip_ai_to_review!].each do |move|
        assert_raises(Aim::Invoice::IllegalTransition) { row.public_send(move, actor: 'x') }
      end
      assert_raises(Aim::Invoice::IllegalTransition) { row.transition_to!('rejected', actor: 'x') }
      assert_equal 'extracting', row.reload.state

      row.update_columns(lease_until: 1.minute.ago)
      assert row.ai_stoppable?, 'once its lease has lapsed the worker has let go'
    end

    test 'skip the AI: to Action Needed, flagged to be typed in, the worker let go' do
      row = invoice(state: 'extracting', owner: 'SCAN02:aim_worker+stop')

      row.skip_ai_to_review!(actor: 'staff@example.test')

      assert_equal ['needs_review', true, nil, nil], [row.state, row.manual_entry, row.command, row.lease_owner]
    end

    test 'start again: back to Waiting for AI with the extract command and no lease' do
      row = invoice(state: 'extracting', owner: 'SCAN02:aim_worker+stop')

      row.restart_ai!(actor: 'staff@example.test')

      assert_equal ['received', 'extract', nil], [row.state, row.command, row.lease_owner]
    end

    test 'rejecting a waiting invoice takes its command, so the worker never reads a rejected one' do
      row = invoice

      row.transition_to!('rejected', actor: 'staff@example.test')

      assert_equal ['rejected', nil], [row.reload.state, row.command]
    end
  end
end
