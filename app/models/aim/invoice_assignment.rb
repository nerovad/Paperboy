# frozen_string_literal: true

module Aim
  # Whose queue an invoice is in. The person's folder it was dropped in, or
  # the BU's shared queue when there was no person; and moving it to another
  # queue, which is not a change of state but is a decision someone made, so
  # it is written as an event. Included by Aim::Invoice.
  module InvoiceAssignment
    extend ActiveSupport::Concern

    SHARED_QUEUE = 'SHARED'

    def queue_owner = assigned_to.presence || SHARED_QUEUE

    # Returns the invoice when it moved, nil when it was already there.
    def reassign!(owner, actor:)
      raise Aim::Invoice::IllegalTransition, "#{batch_id} is finished and cannot be moved to another queue." if terminal?

      target = owner.to_s.squish
      target = nil if target.blank? || target.casecmp?(SHARED_QUEUE)
      was = queue_owner
      return if (target || SHARED_QUEUE).casecmp?(was)

      transaction do
        update!(assigned_to: target, assignment_source: target ? 'reassigned' : nil)
        events.create!(action: 'assignment', from_state: state, to_state: state, actor: actor,
                       note: "moved from #{was} to #{target || SHARED_QUEUE}")
      end
      self
    end
  end
end
