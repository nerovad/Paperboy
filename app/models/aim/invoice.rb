# frozen_string_literal: true

module Aim
  # One invoice, from the moment the watcher mints its batch id. The row is
  # the invoice's state; the files on the share are only its documents.
  #
  # Every change of state writes exactly one Aim::InvoiceEvent, in the same
  # transaction, naming who made it. The caller says who that is on each
  # change -- +actor+ is cleared after every save, so a later change cannot
  # be credited to someone who did not make it.
  #
  # The states are the queues the pipeline really uses, plus the two ways an
  # invoice ends -- archived into Laserfiche, or deleted. Rejection is not an
  # end: the Rejected queue holds an invoice "awaiting archive or follow-up",
  # so it can still be deleted or sent back for another try. Which moves are allowed is declared in TRANSITIONS and
  # enforced on every save, so a move the pipeline cannot make is refused
  # however it is attempted -- through #transition_to! or a bare #update.
  class Invoice < Record
    # Raised by #transition_to! when the move is not one the pipeline makes.
    class IllegalTransition < StandardError; end

    # Kept in step with DOCUMENT_TYPES in script/python/aim/pipeline_common.py,
    # which the workers classify by; test/lib/aim/document_types_test.rb fails
    # if the two lists ever disagree.
    DOCUMENT_TYPES = %w[Invoice Memo Credit Coupon Statement Unknown].freeze
    UNSETTLED_DOCUMENT_TYPE = 'Unknown'

    # Where an invoice can be. Queue names match
    # InvoiceDirectoryService::PATH_ENV; archived and deleted are ends.
    STATES = %w[
      ai_queue pending_vision batch_split ready_to_split reprocess
      vendor_review ready_to_learn low_confidence_review action_needed
      manual_processing sql_queue sql_failed user_approval error_queue
      ready_to_delete archived deleted rejected
    ].freeze

    TERMINAL_STATES = %w[archived deleted].freeze

    # Ways out of review, shared by every queue a person works in.
    REVIEW_EXITS = %w[sql_queue user_approval action_needed reprocess rejected ready_to_delete].freeze

    # What the AI worker can do with a batch, from the AI queue or a retry.
    # error_queue is where a crash lands, so every extraction can reach it.
    EXTRACTION_OUTCOMES = %w[
      pending_vision batch_split vendor_review low_confidence_review
      action_needed sql_queue error_queue
    ].freeze

    TRANSITIONS = {
      'ai_queue' => EXTRACTION_OUTCOMES + %w[rejected ready_to_delete],
      'reprocess' => EXTRACTION_OUTCOMES + %w[rejected ready_to_delete],
      'pending_vision' => %w[sql_queue action_needed low_confidence_review vendor_review],
      'batch_split' => %w[ready_to_split reprocess rejected ready_to_delete],
      'ready_to_split' => %w[reprocess batch_split error_queue],
      'vendor_review' => %w[ready_to_learn action_needed reprocess rejected ready_to_delete],
      'ready_to_learn' => %w[sql_queue vendor_review reprocess error_queue],
      'low_confidence_review' => REVIEW_EXITS,
      'action_needed' => (REVIEW_EXITS - %w[action_needed]) + %w[manual_processing],
      'manual_processing' => REVIEW_EXITS,
      'sql_queue' => %w[archived sql_failed action_needed],
      'sql_failed' => %w[sql_queue action_needed reprocess rejected ready_to_delete],
      'user_approval' => %w[sql_queue action_needed reprocess rejected ready_to_delete],
      'error_queue' => %w[reprocess action_needed rejected ready_to_delete],
      'ready_to_delete' => %w[deleted action_needed],
      'rejected' => %w[ready_to_delete reprocess],
      'archived' => [],
      'deleted' => []
    }.freeze

    has_many :events, -> { order(:created_at, :id) },
             class_name: 'Aim::InvoiceEvent', inverse_of: :invoice, dependent: :restrict_with_exception

    attr_accessor :actor

    validates :batch_id, :state, presence: true
    validates :batch_id, uniqueness: true
    validates :state, inclusion: { in: STATES }, allow_blank: true
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

    # Move to another state, naming who moved it. Raises rather than returning
    # false, because a caller asking for a move the pipeline cannot make has a
    # bug, not a validation message to show someone.
    def transition_to!(new_state, actor:, note: nil)
      unless next_states.include?(new_state.to_s)
        raise IllegalTransition,
              "#{batch_id}: cannot move from #{state} to #{new_state}. " \
              "From #{state} an invoice can go to: #{next_states.presence&.join(', ') || 'nowhere, it is finished'}."
      end

      self.actor = actor
      self.state = new_state.to_s
      @transition_note = note
      save!
    end

    private

    def move_is_one_the_pipeline_makes
      from, to = state_change
      return if from.blank? || !STATES.include?(from) || !STATES.include?(to.to_s)
      return if TRANSITIONS.fetch(from, []).include?(to.to_s)

      errors.add(:state, "cannot move from #{from} to #{to}")
    end

    # An invoice nobody has typed is not ready for the person who has to act
    # on it: AIM staff settle Unknown in QA review first.
    #
    # This is a rule about *moving* an invoice to a user, so it does not apply
    # to a new row. Aim::QueueSync adopts folders that are already sitting in
    # the user queue, and refusing to record where an invoice actually is
    # would lose it rather than protect anyone.
    def document_type_is_settled_for_a_user
      return unless state == 'user_approval'
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
