# frozen_string_literal: true

module Aim
  # One invoice, from the moment the watcher mints its batch id. The row is
  # the invoice's state; the files on the share are only its documents.
  #
  # Every change of state writes exactly one Aim::InvoiceEvent, in the same
  # transaction, naming who made it. The caller says who that is on each
  # change -- +actor+ is cleared after every save, so a later change cannot
  # be credited to someone who did not make it.
  class Invoice < Record
    has_many :events, -> { order(:created_at, :id) },
             class_name: 'Aim::InvoiceEvent', inverse_of: :invoice, dependent: :restrict_with_exception

    attr_accessor :actor

    validates :batch_id, :state, presence: true
    validates :batch_id, uniqueness: true
    validates :budget_unit, format: { with: /\A\d{4}\z/ }, allow_nil: true
    validates :claimed_at, presence: true, if: :claimed_by?
    validates :assignment_source, presence: true, if: :assigned_to?
    validates :actor, presence: true, if: :will_save_change_to_state?

    after_save :record_transition, if: :saved_change_to_state?
    after_save { self.actor = nil }

    private

    def record_transition
      from, to = saved_change_to_state
      events.create!(action: 'transition', from_state: from, to_state: to, actor: actor)
    end
  end
end
