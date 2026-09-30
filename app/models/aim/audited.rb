# frozen_string_literal: true

module Aim
  # AIM's rows keep Paperboy's field-level edit trail (AuditableEdits): one
  # RecordEdit per column a save changed, from what to what, and by whom.
  # AIM's own history (Aim::InvoiceEvent) keeps what happened -- moves between
  # states and queues, commands, who set the coding -- and the edit trail
  # keeps the values.
  #
  # The one AIM difference is who an edit is credited to when nobody is signed
  # in: a job (stamping, coding lookups) or the away sweep. AuditableEdits
  # would record nobody; AIM names the actor the row was given (an invoice's
  # #actor), else itself, as its events do.
  module Audited
    extend ActiveSupport::Concern
    include AuditableEdits

    SYSTEM_ACTOR = 'aim'

    private

    def edit_actor
      return super if Current.user

      { id: nil, name: try(:actor).presence || SYSTEM_ACTOR }
    end
  end
end
