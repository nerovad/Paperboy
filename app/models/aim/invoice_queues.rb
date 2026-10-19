# frozen_string_literal: true

module Aim
  # The screens' queues: a name, a label, and the states each lists. Every
  # state belongs to exactly one queue (the state-machine test checks), so
  # the sidebar, the dashboard and the lists all count the same rows.
  # Included by Aim::Invoice; the constants read as Aim::Invoice::QUEUES.
  module InvoiceQueues
    extend ActiveSupport::Concern

    QUEUES = {
      'received' => { label: 'Waiting for AI', states: %w[received extracting], css_class: 'aim-card-neutral',
                      description: 'Invoices the AI has not finished reading.' },
      # Needs Split is one of Action Needed's reasons, not a queue of its own
      # (Joshua, 2026-09-29).
      'needs_review' => { label: 'Action Needed', states: %w[needs_review needs_split], css_class: 'aim-card-danger',
                          description: 'Needs a person to check: an unknown vendor, a missing field, handwriting, or a PDF holding several invoices.' },
      'ready_for_approval' => { label: 'Ready for Approval', states: %w[ready_for_approval], css_class: 'aim-card-warning',
                                description: 'Read by the AI and waiting for approval.' },
      'in_flight' => { label: 'Exporting', states: %w[approved exporting], css_class: 'aim-card-neutral',
                       description: 'Approved and on the way to billing and Fiscal.' },
      'failed' => { label: 'Failed', states: %w[failed], css_class: 'aim-card-danger',
                    description: 'Something went wrong. Open one to see why.' },
      'exported' => { label: 'Finished', states: %w[exported split], css_class: 'aim-card-neutral',
                      description: 'Done: sent to billing and Fiscal, or split into separate invoices.' },
      'rejected' => { label: 'Rejected', states: %w[rejected], css_class: 'aim-card-neutral',
                      description: 'Turned down, with the reason why.' },
      'deleted' => { label: 'Deleted', states: %w[deleted], css_class: 'aim-card-neutral',
                     description: 'Removed. A copy is kept.' }
    }.freeze

    # The queues a person works.
    WORK_QUEUES = %w[needs_review ready_for_approval failed].freeze

    # Lists of what AIM staff have not yet acknowledged (#169): a rejected or
    # deleted invoice stays until someone says "seen, and it is fine". Shared:
    # one person's acknowledgement clears it for everyone.
    ACKNOWLEDGED_QUEUES = %w[rejected deleted].freeze

    included do
      scope :in_queue, ->(queue) { where(state: QUEUES.fetch(queue.to_s).fetch(:states)) }
      scope :newest_first, -> { order(created_at: :desc, id: :desc) }
      scope :unacknowledged, -> { where(acknowledged_at: nil) }

      # The finished lists window and search on when an invoice finished
      # (#169); a restore takes it back out. The worker's Db#transition does
      # the same. Any move clears an acknowledgement, so an invoice rejected
      # again comes back as new.
      before_save :date_the_finish, if: :will_save_change_to_state?
    end

    class_methods do
      def queue_for(state)
        QUEUES.find { |_, queue| queue[:states].include?(state.to_s) }&.first
      end

      # How many invoices each queue holds, for the sidebar and the dashboard.
      # Rejected and Deleted count what is still to acknowledge.
      def queue_counts
        by_state = group(:state).count
        pending = unacknowledged.where(state: ACKNOWLEDGED_QUEUES).group(:state).count
        QUEUES.to_h do |name, queue|
          counted = ACKNOWLEDGED_QUEUES.include?(name) ? pending : by_state
          [name, queue[:states].sum { |state| counted.fetch(state, 0) }]
        end
      end
    end

    def queue = self.class.queue_for(state)

    def acknowledgeable? = ACKNOWLEDGED_QUEUES.include?(state) && acknowledged_at.nil?

    # Seen, and fine: off the Rejected or Deleted list, with a history line.
    # Nothing happens (nil) when there is nothing to acknowledge. Written with
    # update_columns, so the claim, updated_at and the edit trail are
    # untouched; the event is the record.
    def acknowledge!(actor:, name: nil)
      return unless acknowledgeable?

      transaction do
        update_columns(acknowledged_at: Time.current, acknowledged_by: actor)
        events.create!(action: 'acknowledged', actor: actor, note: "acknowledged by #{name.presence || actor}")
      end
    end

    private

    def date_the_finish
      self.finished_at = terminal? ? Time.current : nil
      self.acknowledged_at = nil
      self.acknowledged_by = nil
    end
  end
end
