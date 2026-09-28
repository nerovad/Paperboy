# frozen_string_literal: true

module Aim
  # One invoice, from the moment intake mints its batch id. The row is the
  # invoice: its state, its fields, what the worker should do next, and why a
  # person is needed. The PDF sits in the store and never moves. AIM v2.
  #
  # Every change of state writes exactly one Aim::InvoiceEvent, in the same
  # transaction, naming who made it. +actor+ is cleared after every save, so a
  # later change cannot be credited to someone who did not make it.
  #
  # Which moves are allowed is declared in TRANSITIONS and enforced on every
  # save, so a move the pipeline cannot make is refused however it is
  # attempted -- through #transition_to! or a bare #update. There is no "sync"
  # any more: nothing else knows where an invoice is.
  class Invoice < Record
    include Aim::InvoiceQueues
    include Aim::InvoiceCommands
    include Aim::InvoiceAssignment
    include Aim::InvoiceNaming
    include Aim::InvoiceCoding

    # Raised by #transition_to! when the move is not one the pipeline makes.
    class IllegalTransition < StandardError; end

    # Kept in step with DOCUMENT_TYPES in script/python/aim/pipeline_common.py;
    # test/lib/aim/document_types_test.rb fails if the two lists disagree.
    DOCUMENT_TYPES = %w[Invoice Memo Credit Coupon Statement Unknown].freeze
    UNSETTLED_DOCUMENT_TYPE = 'Unknown'

    STATES = %w[
      received extracting needs_review needs_split ready_for_approval
      approved exporting exported failed rejected deleted split
    ].freeze

    TERMINAL_STATES = %w[exported rejected deleted split].freeze

    # Why a person is needed. The old review queues, as one column.
    REVIEW_REASONS = %w[
      unknown_type unknown_vendor missing_fields low_confidence handwritten
      extraction_error split_error export_error
    ].freeze

    # What the worker does next. NULL means nothing.
    COMMANDS = %w[extract split export].freeze

    # A rejected or deleted invoice is finished, but AIM staff may bring one
    # back, with a reason: to Action Needed, or straight to its owner.
    RESTORE_STATES = %w[needs_review ready_for_approval].freeze

    TRANSITIONS = {
      'received' => %w[extracting rejected deleted],
      'extracting' => %w[needs_review needs_split ready_for_approval failed received],
      'needs_review' => %w[ready_for_approval received needs_split rejected deleted],
      'needs_split' => %w[split received rejected deleted],
      'ready_for_approval' => %w[approved needs_review rejected deleted],
      'approved' => %w[exporting needs_review],
      'exporting' => %w[exported failed],
      'failed' => %w[received approved needs_review rejected deleted],
      'exported' => [],
      'rejected' => RESTORE_STATES,
      'deleted' => RESTORE_STATES,
      'split' => []
    }.freeze

    # The columns a reviewer may change on the review page.
    EDITABLE_FIELDS = %w[
      document_type vendor_name invoice_number invoice_date invoice_total subtotal sales_tax
      order_number customer_number budget_unit submitter notes
    ].freeze

    has_many :events, -> { order(:created_at, :id) },
             class_name: 'Aim::InvoiceEvent', inverse_of: :invoice, dependent: :restrict_with_exception
    belongs_to :parent, class_name: 'Aim::Invoice', optional: true
    has_many :children, class_name: 'Aim::Invoice', foreign_key: :parent_id, inverse_of: :parent,
                        dependent: :restrict_with_exception

    attr_accessor :actor

    validates :batch_id, :state, presence: true
    validates :batch_id, uniqueness: true
    validates :state, inclusion: { in: STATES }, allow_blank: true
    validates :command, inclusion: { in: COMMANDS }, allow_nil: true
    validates :review_reason, inclusion: { in: REVIEW_REASONS }, allow_nil: true
    validates :document_type, inclusion: { in: DOCUMENT_TYPES }, allow_nil: true
    validates :budget_unit, format: { with: /\A\d{4}\z/ }, allow_nil: true
    validates :claimed_at, presence: true, if: :claimed_by?
    validates :assignment_source, presence: true, if: :assigned_to?
    validates :actor, presence: true, if: :will_save_change_to_state?
    validate :move_is_one_the_pipeline_makes, if: :state_changed?
    validate :document_type_is_settled_for_a_user, if: -> { state_changed? && persisted? }

    after_save :record_transition, if: :saved_change_to_state?
    after_save { self.actor = nil }

    def terminal? = TERMINAL_STATES.include?(state)

    def next_states = TRANSITIONS.fetch(state, [])

    def can_move_to?(new_state) = next_states.include?(new_state.to_s)

    # Move to another state, naming who moved it. Raises rather than returning
    # false, because a caller asking for a move the pipeline cannot make has a
    # bug, not a validation message to show someone.
    def transition_to!(new_state, actor:, note: nil, **changes)
      unless can_move_to?(new_state)
        raise IllegalTransition,
              "#{batch_id}: cannot move from #{state} to #{new_state}. " \
              "From #{state} an invoice can go to: #{next_states.presence&.join(', ') || 'nowhere, it is finished'}."
      end

      self.actor = actor
      assign_attributes(changes)
      self.state = new_state.to_s
      @transition_note = note
      save!
    end

    # What a user's approval, and billing, cannot do without.
    def ready_for_a_user?
      document_type.present? && document_type != UNSETTLED_DOCUMENT_TYPE &&
        vendor_name.present? && invoice_number.present?
    end

    def missing_for_a_user
      missing = []
      missing << 'a document type' if document_type.blank? || document_type == UNSETTLED_DOCUMENT_TYPE
      missing << 'a vendor name' if vendor_name.blank?
      missing << 'an invoice number' if invoice_number.blank?
      missing
    end

    private

    def move_is_one_the_pipeline_makes
      from, to = state_change
      return if from.blank? || !STATES.include?(from) || !STATES.include?(to.to_s)
      return if TRANSITIONS.fetch(from, []).include?(to.to_s)

      errors.add(:state, "cannot move from #{from} to #{to}")
    end

    # An invoice nobody has typed is not ready for the person who has to act
    # on it: AIM staff settle Unknown in review first.
    def document_type_is_settled_for_a_user
      return unless state == 'ready_for_approval'
      return if document_type.present? && document_type != UNSETTLED_DOCUMENT_TYPE

      errors.add(:document_type, 'must be settled before an invoice reaches a user')
    end

    def record_transition
      from, to = saved_change_to_state
      events.create!(action: 'transition', from_state: from, to_state: to, actor: actor, note: @transition_note)
      @transition_note = nil
    end
  end
end
