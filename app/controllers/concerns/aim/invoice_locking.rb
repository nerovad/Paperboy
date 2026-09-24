# frozen_string_literal: true

module Aim
  # The review page's presence, and Claim.
  #
  # While someone works an invoice their page checks in (lock) every half
  # minute, which keeps the working lock fresh; leaving the page lets it go
  # (unlock). A lost goodbye does not matter: the lock lapses by itself
  # Aim::Invoice::LOCK_SECONDS after the last check-in.
  #
  # Claim is not the lock. It moves the invoice into your queue, for AIM staff
  # looking at an invoice in the shared queue or someone else's.
  module InvoiceLocking
    extend ActiveSupport::Concern

    def lock
      if @invoice.held_by?(current_user_email) || (editor? && !@invoice.claimed_by_other?(current_user_email))
        @invoice.claim!(current_user_email, name: current_user_name)
        head :no_content
      else
        head :conflict
      end
    end

    def unlock
      @invoice.release_claim! if @invoice.claimed_by.to_s.casecmp?(current_user_email.to_s)
      head :no_content
    end

    def claim
      return redirect_to(aim_invoice_path(@invoice.batch_id, queue: @queue), alert: 'This invoice cannot be claimed.') unless claimable?

      @invoice.reassign!(current_user_employee_id, actor: current_user_email)
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue), notice: 'Claimed. It is in your queue now.'
    rescue Aim::Invoice::IllegalTransition, ActiveRecord::RecordInvalid => e
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue), alert: e.message
    end
  end
end
