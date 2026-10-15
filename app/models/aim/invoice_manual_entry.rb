# frozen_string_literal: true

module Aim
  # Manual Data Entry Needed (#131). An invoice uploaded without the AI, or
  # sent to someone's queue by an AIM Admin from anywhere in the pipeline,
  # waits in that queue flagged for a person to type in. The flag clears once
  # what a user needs is filled in (Aim::Invoice#ready_for_a_user?); Approve
  # refuses until then anyway. Included by Aim::Invoice.
  module InvoiceManualEntry
    # Where an AIM Admin may send an invoice to a queue from: not while the
    # worker holds it (extracting, exporting), and not once it is approved or
    # finished.
    SENDABLE_STATES = %w[received needs_review needs_split failed ready_for_approval].freeze

    def sendable? = SENDABLE_STATES.include?(state)

    # To +owner+'s queue (an employee id, or the shared queue), in Ready for
    # Approval, the worker's pending command dropped; +manual+ flags it.
    def send_to_queue!(owner, actor:, reason:, manual: false, by: nil)
      raise Aim::Invoice::IllegalTransition, "#{batch_id} is #{state}; it cannot be sent to a queue from there." unless sendable?

      transaction do
        unless state == 'ready_for_approval'
          transition_to!('ready_for_approval', actor: actor, note: "sent to a queue: #{reason}",
                                               command: nil, review_reason: nil, lease_owner: nil, lease_until: nil)
        end
        reassign!(owner, actor: actor, by: by)
        flag_manual_entry!(actor: actor, note: "Manual Data Entry Needed: #{reason}") if manual
      end
    end

    def flag_manual_entry!(actor:, note: 'Manual Data Entry Needed')
      update!(manual_entry: true)
      events.create!(action: 'manual_entry', actor: actor, from_state: state, to_state: state, note: note)
    end

    # Clears the flag once the fields a user needs are in.
    def finish_manual_entry!(actor:)
      return unless manual_entry && ready_for_a_user?

      update!(manual_entry: false)
      events.create!(action: 'manual_entry', actor: actor, from_state: state, to_state: state, note: 'Manual data entry done')
    end
  end
end
