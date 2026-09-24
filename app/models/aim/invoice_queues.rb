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
      'needs_review' => { label: 'Action Needed', states: %w[needs_review], css_class: 'aim-card-danger',
                          description: 'The AI needs a person: an unknown vendor, a missing field, handwriting.' },
      'needs_split' => { label: 'Needs Split', states: %w[needs_split], css_class: 'aim-card-info',
                         description: 'PDFs the AI thinks hold more than one invoice.' },
      'ready_for_approval' => { label: 'Ready for Approval', states: %w[ready_for_approval], css_class: 'aim-card-warning',
                                description: 'Extracted and waiting for the owner to approve.' },
      'in_flight' => { label: 'Exporting', states: %w[approved exporting], css_class: 'aim-card-neutral',
                       description: 'Approved and on the way to billing and Laserfiche.' },
      'failed' => { label: 'Failed', states: %w[failed], css_class: 'aim-card-danger',
                    description: 'The worker could not finish. See the note on each.' },
      'exported' => { label: 'Finished', states: %w[exported split], css_class: 'aim-card-neutral',
                      description: 'In billing and Laserfiche, or split into the invoices it held.' },
      'rejected' => { label: 'Rejected', states: %w[rejected], css_class: 'aim-card-neutral',
                      description: 'Sent back to the submitter.' },
      'deleted' => { label: 'Deleted', states: %w[deleted], css_class: 'aim-card-neutral',
                     description: 'Removed by a reviewer; a copy is kept.' }
    }.freeze

    # The queues a person works.
    WORK_QUEUES = %w[needs_review needs_split ready_for_approval failed].freeze

    included do
      scope :in_queue, ->(queue) { where(state: QUEUES.fetch(queue.to_s).fetch(:states)) }
      scope :newest_first, -> { order(created_at: :desc, id: :desc) }
    end

    class_methods do
      def queue_for(state)
        QUEUES.find { |_, queue| queue[:states].include?(state.to_s) }&.first
      end

      # How many invoices each queue holds, for the sidebar and the dashboard.
      def queue_counts
        by_state = group(:state).count
        QUEUES.to_h { |name, queue| [name, queue[:states].sum { |state| by_state.fetch(state, 0) }] }
      end
    end

    def queue = self.class.queue_for(state)
  end
end
