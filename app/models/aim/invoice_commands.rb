# frozen_string_literal: true

module Aim
  # What the screens ask the worker for, and who is holding an invoice.
  # Included by Aim::Invoice.
  module InvoiceCommands
    extend ActiveSupport::Concern

    # What the screens ask the worker for. Each is a state and a command in one
    # save, so the worker can never find a command on a row in the wrong state.
    def request_extract!(actor:, note: nil, split_check: self.split_check)
      transition_to!('received', actor: actor, note: note, command: 'extract', split_check: split_check,
                                 lease_owner: nil, lease_until: nil, review_reason: nil, review_note: nil)
    end

    def request_export!(actor:, note: nil)
      transition_to!('approved', actor: actor, note: note, command: 'export', lease_owner: nil, lease_until: nil)
    end

    # A split is approved in place: the state stays needs_split until the
    # worker has cut the PDF and made the children.
    def request_split!(manifest, actor:)
      update!(manifest: manifest.to_json, command: 'split', lease_owner: nil, lease_until: nil)
      events.create!(action: 'command', from_state: state, to_state: state, actor: actor, note: 'split approved')
    end

    def manifest_data
      manifest.present? ? JSON.parse(manifest) : {}
    rescue JSON::ParserError
      {}
    end

    def extracted_data
      extracted.present? ? JSON.parse(extracted) : {}
    rescue JSON::ParserError
      {}
    end

    # The working lock: whoever has the review page open to work the invoice.
    # It is held only while their page keeps checking in (aim_presence), so
    # it lifts on its own LOCK_SECONDS after they leave -- a closed laptop can
    # never leave an invoice stuck. Written past validation and without an
    # event: it is presence, not a change to the invoice. Claiming an invoice
    # is something else: it moves it to your queue (Aim::InvoiceAssignment).
    LOCK_SECONDS = 90

    # A rejected or deleted invoice AIM staff may bring back (Aim::Invoice::RESTORE_STATES).
    def restorable? = %w[rejected deleted].include?(state)

    def claim!(email, name: nil)
      update_columns(claimed_by: email, claimed_by_name: name, claimed_at: Time.current, updated_at: Time.current)
    end

    def release_claim!
      update_columns(claimed_by: nil, claimed_by_name: nil, claimed_at: nil, updated_at: Time.current)
    end

    def lock_fresh? = claimed_by.present? && claimed_at.present? && claimed_at > LOCK_SECONDS.seconds.ago

    # Named apart from the claimed_by? attribute predicate Active Record defines.
    def held_by?(email) = lock_fresh? && claimed_by.to_s.casecmp?(email.to_s)

    def claimed_by_other?(email) = lock_fresh? && !claimed_by.to_s.casecmp?(email.to_s)
  end
end
