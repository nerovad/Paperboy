# frozen_string_literal: true

module Aim
  # Move several invoices at once, from the checkboxes on a queue. Each one is
  # checked on its own: an invoice you could not move with its own Move button
  # is skipped here too, and the message says how many.
  module InvoiceBulkMoves
    extend ActiveSupport::Concern

    def reassign_many
      owner = params[:destination] == 'shared' ? Aim::Invoice::SHARED_QUEUE : params[:owner]
      if owner != Aim::Invoice::SHARED_QUEUE && !Aim::Users.member?(owner)
        return redirect_back_or_to(aim_my_queue_path, alert: 'That person does not work AIM, so they have no queue.')
      end

      moved, skipped = move_each(Array(params[:ids]).map(&:to_s).uniq, owner)
      notice = "Moved #{helpers.pluralize(moved, 'invoice')}."
      notice += " #{helpers.pluralize(skipped, 'invoice')} could not be moved by you and were left." if skipped.positive?
      redirect_back_or_to aim_my_queue_path, notice: notice
    end

    private

    def move_each(batch_ids, owner)
      moved = skipped = 0
      Aim::Invoice.where(batch_id: batch_ids).find_each do |invoice|
        @invoice = invoice
        next skipped += 1 unless movable_by_me?

        # Already in that queue counts as neither moved nor skipped.
        moved += 1 if invoice.reassign!(owner, actor: current_user_email)
      rescue Aim::Invoice::IllegalTransition, ActiveRecord::RecordInvalid
        skipped += 1
      end
      [moved, skipped]
    end

    # What the single Move allows: AIM staff move any open invoice; anyone
    # else their own ready invoices and those in shared queues they cover.
    def movable_by_me?
      return false if @invoice.terminal?
      return true if staff?

      @invoice.state == 'ready_for_approval' && (mine? || shared_to_me?)
    end
  end
end
