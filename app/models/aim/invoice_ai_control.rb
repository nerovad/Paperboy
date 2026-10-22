# frozen_string_literal: true

module Aim
  # Waiting for AI (#192): what AIM staff may do with an invoice the AI has
  # not finished. Hold it -- it stays in Waiting for AI, and the worker, which
  # only takes a row with a command, leaves it until the hold is released --
  # or take it from the AI: to Action Needed to be typed in, to a queue,
  # rejected, deleted, or read again from the start.
  #
  # Taking it clears the worker's lease. A worker that can be stopped (its
  # lease name ends in STOPPABLE; script/python/aim/v2/store.py) checks its
  # lease as it reads and before every write, so it stops at its next check
  # and writes nothing. One that cannot would write over the person's choice,
  # so while such a worker is reading, nothing here is offered or allowed.
  # Included by Aim::Invoice.
  module InvoiceAiControl
    STOPPABLE = '+stop'
    # The states the worker has work in (a command) -- reached with the
    # command set by the caller. A move a person makes to any other state
    # takes the row from the worker: no command, no lease, so the worker
    # never picks up, or goes on with, one a person has moved
    # (Aim::Invoice#transition_to!).
    WORKER_STATES = %w[received approved exporting extracting].freeze
    WORKER_LETS_GO = { command: nil, lease_owner: nil, lease_until: nil }.freeze
    WAITING_STATES = %w[received extracting].freeze
    HOLD_NOTE = 'on hold: the AI leaves it until the hold is released'

    def waiting_for_ai? = WAITING_STATES.include?(state)

    def on_hold? = state == 'received' && command.nil?

    def lease_live? = lease_until.present? && lease_until > Time.current

    # Whether a person may take it from the AI now: it is waiting, and either
    # no worker has it or the one that has it gives it up.
    def ai_stoppable? = waiting_for_ai? && (!lease_live? || lease_owner.to_s.end_with?(STOPPABLE))

    def hold_ai!(actor:, reason: nil)
      raise Aim::Invoice::IllegalTransition, "#{batch_id} is already on hold." if on_hold?

      note = [HOLD_NOTE, reason.presence].compact.join(': ')
      return transition_to!('received', actor: actor, note: note, command: nil, lease_owner: nil, lease_until: nil) if state == 'extracting'

      check_ai_stoppable!
      update!(command: nil, lease_owner: nil, lease_until: nil)
      events.create!(action: 'hold', actor: actor, from_state: state, to_state: state, note: note)
    end

    def release_hold!(actor:)
      raise Aim::Invoice::IllegalTransition, "#{batch_id} is not on hold." unless on_hold?

      update!(command: 'extract')
      events.create!(action: 'hold', actor: actor, from_state: state, to_state: state, note: 'hold released: back to the AI')
    end

    # The AI starts again from the first page.
    def restart_ai!(actor:)
      transition_to!('received', actor: actor, note: 'AI stopped and started again', command: 'extract',
                                 lease_owner: nil, lease_until: nil)
    end

    # Skip the AI: AIM staff type it in, in Action Needed.
    def skip_ai_to_review!(actor:)
      transition_to!('needs_review', actor: actor, note: 'AI skipped: to Action Needed to be typed in',
                                     manual_entry: true, review_reason: nil)
    end

    private

    # Every move a person makes from extracting goes through here
    # (Aim::Invoice#transition_to!).
    def check_ai_stoppable!
      return if !waiting_for_ai? || ai_stoppable?

      raise Aim::Invoice::IllegalTransition,
            "#{batch_id}: the AI is reading it with a worker that cannot be stopped. Wait for it, or update the worker."
    end
  end
end
