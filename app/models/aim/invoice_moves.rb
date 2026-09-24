# frozen_string_literal: true

module Aim
  # Where an invoice's files went, and who is holding it -- recorded on the row
  # however the move happened. Included by Aim::Invoice. Plan step 5.7b.
  module InvoiceMoves
    extend ActiveSupport::Concern

    class_methods do
      # Record a move for a batch that may have no row yet: one is created
      # where the files are, which is how an invoice the database never saw is
      # adopted.
      def record_move!(batch_id, new_state, actor:, note: nil)
        invoice = find_by(batch_id: batch_id)
        return create!(batch_id: batch_id, state: new_state.to_s, actor: actor) if invoice.nil?

        invoice.record_move!(new_state, actor: actor, note: note)
      end
    end

    # Record that the invoice's files are now in +new_state+, however they got
    # there. A move the pipeline makes is a transition. One it does not -- a
    # folder dragged by hand, a screen acting on a stale page, a move the
    # document-type rule would have refused -- is written down as a +sync+
    # event saying so, never refused: the file has already moved, and a row
    # that refused to follow would be wrong about where the invoice is.
    def record_move!(new_state, actor:, note: nil)
      new_state = new_state.to_s
      return self if state == new_state

      transition_to!(new_state, actor: actor, note: note)
      self
    rescue Aim::Invoice::IllegalTransition, ActiveRecord::RecordInvalid => e
      restore_attributes
      record_out_of_band_move(new_state, actor: actor, note: note, reason: e)
      self
    end

    # Claims live on the row, and the queue screens read them from it. They are
    # still written to the folder's .claim.json as well, because the Paperboy
    # inbox reads that until 9.5. Written past validation and without an event:
    # a claim is a reservation, not a change to the invoice.
    def claim!(email, name: nil)
      update_columns(claimed_by: email, claimed_by_name: name, claimed_at: Time.current, updated_at: Time.current)
    end

    def release_claim!
      update_columns(claimed_by: nil, claimed_by_name: nil, claimed_at: nil, updated_at: Time.current)
    end

    private

    def record_out_of_band_move(new_state, actor:, note:, reason:)
      from = state
      explanation = reason.is_a?(Aim::Invoice::IllegalTransition) ? 'moved outside the pipeline' : reason.message
      update_columns(state: new_state, updated_at: Time.current)
      events.create!(action: 'sync', from_state: from, to_state: new_state, actor: actor,
                     note: [note, explanation].compact_blank.join(' -- '))
    end
  end
end
