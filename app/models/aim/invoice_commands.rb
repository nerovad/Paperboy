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

    # The note on a split started by hand, which is how Keep as One finds it.
    SPLIT_BY_HAND = 'split started by hand'
    # Where a person may start one: before approval, and not while the AI has
    # it (extracting may move to needs_split too, but that is the worker's).
    SPLIT_BY_HAND_FROM = %w[needs_review ready_for_approval].freeze

    # Split by hand (#192): the AI took it for one invoice, a person sees
    # several. To Needs Split, with every page in one invoice for them to
    # divide; nothing is cut until they approve the split. No vendor or
    # number: the AI reads each piece for its own.
    def start_split!(actor:)
      raise Aim::Invoice::IllegalTransition, "#{batch_id}: only an invoice in Action Needed or Ready for Approval is split by hand." \
        unless SPLIT_BY_HAND_FROM.include?(state)

      whole = { 'pages' => (1..page_count.to_i).to_a }
      transition_to!('needs_split', actor: actor, note: SPLIT_BY_HAND, command: nil, lease_owner: nil, lease_until: nil,
                                    manifest: manifest_data.merge('invoices' => [whole]).to_json)
    end

    # Where a split started by hand came from, to go back to as one invoice;
    # nil for one the AI asked for, or when it is not waiting to be split.
    def split_started_from
      return unless state == 'needs_split'

      event = events.where(to_state: 'needs_split').order(:id).last
      event.from_state if event&.note == SPLIT_BY_HAND
    end

    # The split's page ranges from the pages each invoice starts on, as the
    # PDF editor's "New invoice starts here" marks them (#192). Page 1 always
    # starts one. Each invoice keeps the vendor and number its row had.
    def mark_split_starts!(starts)
      last_page = page_count.to_i
      firsts = ([1] + Array(starts).map(&:to_i)).grep(1..last_page).uniq.sort
      rows = Array(manifest_data['invoices'])
      invoices = firsts.each_with_index.map do |first, index|
        (rows[index] || {}).merge('pages' => (first..((firsts[index + 1] || (last_page + 1)) - 1)).to_a)
      end
      update!(manifest: manifest_data.merge('invoices' => invoices).to_json)
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
    # Not once its PDF has been purged (#170): there is nothing left to work.
    def restorable? = %w[rejected deleted].include?(state) && pdf_purged_at.nil?

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
