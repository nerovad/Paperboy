# frozen_string_literal: true

module Aim
  # Bring a rejected or deleted invoice back, for AIM staff, with a reason:
  # to Action Needed for another look, or to Ready for Approval for its owner.
  # The reason goes into Notes and the history, as for Reject and Delete.
  module InvoiceRestore
    extend ActiveSupport::Concern

    RESTORE_TO = { 'Restore to Action Needed' => 'needs_review',
                   'Restore to Ready for Approval' => 'ready_for_approval' }.freeze

    def restore
      target = RESTORE_TO[params[:commit].to_s]
      return restore_refused('Only AIM Admins can restore invoices.') unless staff? && @invoice.restorable?
      return restore_refused('Choose where to restore it.') if target.nil?
      return restore_refused('Restoring needs a reason.') if reason.blank?

      was = @invoice.state
      @invoice.transition_to!(target, actor: current_user_email, note: "restored from #{was}; reason: #{reason}",
                                      notes: notes_with("Restored from #{was}"))
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @invoice.queue),
                  notice: "Restored to #{helpers.aim_queue_label(@invoice.queue)}."
    rescue Aim::Invoice::IllegalTransition, ActiveRecord::RecordInvalid => e
      restore_refused(e.message)
    end

    private

    def restore_refused(message)
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue), alert: message
    end
  end
end
