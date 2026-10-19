# frozen_string_literal: true

module Aim
  # Possible duplicates (#131). An invoice waiting on a person -- Action Needed
  # or Ready for Approval -- whose vendor, invoice number and total match an
  # earlier invoice's is flagged for AIM staff: Action Needed, reason
  # "duplicate", linked to the other (duplicate_of). Staff reject it as a
  # duplicate, mark it the replacement of the other, or say it is not a
  # duplicate. The details last checked are kept, so it is checked again only
  # when they change, and "not a duplicate" sticks. Only the later of two is
  # flagged, and only invoices that arrived from AIM_DUPLICATE_CHECK_FROM on
  # (default the day this was built), so going live never pulls work already
  # in people's queues; older invoices are still what new ones are compared
  # with. Included by Aim::Invoice.
  module InvoiceDuplicates
    extend ActiveSupport::Concern

    CHECK_STATES = %w[needs_review ready_for_approval].freeze
    # The original is past the point of being replaced (#160): approved, or
    # with Fiscal. The two can still be compared, and this one re-processed.
    PROCESSED_STATES = %w[approved exporting exported].freeze
    ACTOR = 'AIM duplicate check'
    CHECK_FROM_DEFAULT = '2026-10-15'

    included do
      belongs_to :duplicate_of, class_name: 'Aim::Invoice', optional: true
      belongs_to :replaces, class_name: 'Aim::Invoice', foreign_key: :replaces_invoice_id, optional: true
    end

    class_methods do
      # Every invoice waiting on a person that has not been checked as it is.
      # Straight to Fiscal is not stopped: its job notes the duplicate itself
      # (note_known_duplicate!) and sends it on.
      def check_duplicates!
        where(state: CHECK_STATES, duplicate_of_id: nil, straight_to_fiscal_by: nil).where(created_at: check_from..)
                                                                                    .find_each(&:check_duplicate!)
      end

      def check_from
        Time.zone.parse(ENV.fetch('AIM_DUPLICATE_CHECK_FROM', CHECK_FROM_DEFAULT).presence || CHECK_FROM_DEFAULT)
      end

      def duplicate_text(value) = value.to_s.downcase.gsub(/\s+/, '')
    end

    # vendor|number|total, compared without case or spaces; nil while any is
    # missing.
    def duplicate_key
      return if vendor_name.blank? || invoice_number.blank? || invoice_total.nil?

      [self.class.duplicate_text(vendor_name), self.class.duplicate_text(invoice_number), format('%.2f', invoice_total)].join('|')
    end

    def possible_duplicate? = review_reason == 'duplicate' && duplicate_of_id.present?

    # Flagged, then sent on by AIM staff (Send to a queue, Send to Approval):
    # still linked, so whoever has it now is told (#160).
    def known_duplicate? = duplicate_of_id.present? && review_reason != 'duplicate'

    def original_processed? = duplicate_of.present? && PROCESSED_STATES.include?(duplicate_of.state)

    def replaced_by = self.class.find_by(replaces_invoice_id: id)

    # The earliest earlier invoice, not deleted, with the same details; not
    # one this replaces or that replaces it.
    def find_duplicate
      key = duplicate_key
      return if key.nil?

      self.class.where(invoice_total: invoice_total).where(id: ...id).where.not(state: 'deleted')
          .where.not(id: replaces_invoice_id).where('replaces_invoice_id IS NULL OR replaces_invoice_id <> ?', id).order(:id)
          .find { |other| other.duplicate_key == key }
    end

    def check_duplicate!
      key = duplicate_key
      return if key.nil? || key == duplicate_checked_key

      other = find_duplicate
      update_columns(duplicate_checked_key: key) # a note to itself, not a move: no history line
      flag_duplicate!(other) if other
    end

    # Straight to Fiscal (#160): a duplicate is linked and noted at both ends,
    # but not stopped -- it goes on to Fiscal as a known duplicate, which
    # Fiscal sees on its row and its page. Checked once per set of details.
    def note_known_duplicate!(actor: ACTOR)
      key = duplicate_key
      return if key.nil? || key == duplicate_checked_key || created_at < self.class.check_from

      other = find_duplicate
      update_columns(duplicate_checked_key: key, duplicate_of_id: other&.id)
      return if other.nil?

      events.create!(action: 'duplicate', actor: actor, from_state: state, to_state: state,
                     note: "Known duplicate of #{other.batch_id} (same vendor, invoice number and total); sent straight to Fiscal")
      other.events.create!(action: 'duplicate', actor: actor, from_state: other.state, to_state: other.state,
                           note: "#{batch_id} may be a duplicate of this one; it was sent straight to Fiscal")
    end

    # Where this invoice stands as a duplicate, for its pill (#160): :possible
    # (waiting on AIM staff), :rejected (rejected as one), :replaced,
    # :replacement, :known (sent on knowing it), or nil. +replaced+ says
    # whether another invoice replaces this one, when the caller knows.
    def duplicate_status(replaced: nil)
      replaced = replaced_by.present? if replaced.nil?
      if review_reason == 'duplicate' && duplicate_of_id.present?
        state == 'rejected' ? :rejected : :possible
      elsif replaced then :replaced
      elsif replaces_invoice_id.present? then :replacement
      elsif duplicate_of_id.present? then :known
      end
    end

    def flag_duplicate!(other, actor: ACTOR)
      note = "Possible duplicate of #{other.batch_id} (same vendor, invoice number and total)"
      if state == 'needs_review'
        update!(review_reason: 'duplicate', duplicate_of_id: other.id)
        events.create!(action: 'duplicate', actor: actor, from_state: state, to_state: state, note: note)
      else
        transition_to!('needs_review', actor: actor, note: note, review_reason: 'duplicate', duplicate_of_id: other.id)
      end
      other.events.create!(action: 'duplicate', actor: actor, from_state: other.state, to_state: other.state,
                           note: "#{batch_id} may be a duplicate of this one")
    end

    # Staff: not a duplicate. Back to an ordinary Action Needed invoice.
    def clear_duplicate!(actor:)
      other = duplicate_of
      update!(review_reason: nil, duplicate_of_id: nil, duplicate_checked_key: duplicate_key)
      events.create!(action: 'duplicate', actor: actor, from_state: state, to_state: state,
                     note: "Not a duplicate of #{other&.batch_id}")
    end

    # Staff: this replaces the other, from the prompt (#160). This one goes to
    # +owner+'s queue -- or, with none, the original's -- and the original is
    # rejected as replaced, with +notes+ (its notes plus the line saying so).
    # All or nothing. The original's PDF copy for the rejected folder is the
    # caller's. A second call finds no duplicate left to replace and raises.
    def replace_original!(actor:, owner: nil, by: nil, notes: nil)
      other = duplicate_of
      raise Aim::Invoice::IllegalTransition, "#{batch_id} is not a possible duplicate." unless possible_duplicate?
      raise Aim::Invoice::IllegalTransition, "#{other.batch_id} has already been processed." if original_processed?

      transaction do
        unit = owner.nil? && other.shared_queue? ? other.budget_unit : nil
        mark_replacement!(actor: actor)
        send_to_queue!(owner.nil? ? other.assigned_employee_id.to_s : owner, actor: actor, by: by, unit: unit,
                                                                             reason: "replaces #{other.batch_id}")
        other.transition_to!('rejected', actor: actor, notes: notes || other.notes, note: "reason: Replaced by #{batch_id}") unless %w[rejected deleted].include?(other.state)
      end
    end

    # Staff: this replaces the other. Both say so, with links.
    def mark_replacement!(actor:)
      other = duplicate_of
      transaction do
        update!(review_reason: nil, duplicate_of_id: nil, replaces_invoice_id: other.id, duplicate_checked_key: duplicate_key)
        events.create!(action: 'duplicate', actor: actor, from_state: state, to_state: state, note: "Replaces #{other.batch_id}")
        other.events.create!(action: 'duplicate', actor: actor, from_state: other.state, to_state: other.state,
                             note: "Replaced by #{batch_id}")
      end
    end
  end
end
