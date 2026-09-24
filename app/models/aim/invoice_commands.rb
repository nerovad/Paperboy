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

    # Claims are a reservation, not a change to the invoice: written past
    # validation and without an event.
    def claim!(email, name: nil)
      update_columns(claimed_by: email, claimed_by_name: name, claimed_at: Time.current, updated_at: Time.current)
    end

    def release_claim!
      update_columns(claimed_by: nil, claimed_by_name: nil, claimed_at: nil, updated_at: Time.current)
    end

    # Named apart from the claimed_by? attribute predicate Active Record defines.
    def held_by?(email) = claimed_by.present? && claimed_by.to_s.casecmp?(email.to_s)

    def claimed_by_other?(email) = claimed_by.present? && !held_by?(email)
  end
end
