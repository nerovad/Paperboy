# frozen_string_literal: true

require 'fileutils'

module Aim
  # What each button on the review page does. Every one is a move of the row's
  # state through Aim::Invoice#transition_to!, so a move the pipeline does not
  # make is refused with its reason (the controller turns IllegalTransition
  # into an alert). The worker is asked for work by setting the row's command.
  #
  # Each button posts invoice_action=<value>, never its label (as Fiscal's
  # post fiscal_action), so a button can be renamed without breaking what it
  # does.
  module InvoiceActions
    extend ActiveSupport::Concern

    ACTIONS = {
      'save' => :save_only,
      'send_to_approval' => :send_to_approval,
      'approve' => :approve,
      'send_back' => :send_back,
      'retry_ai' => :retry_ai,
      'reject' => :reject,
      'delete' => :delete_invoice,
      'learn_and_retry' => :learn_and_retry,
      'learn_and_send' => :learn_and_send,
      'retry_export' => :retry_export
    }.merge(Aim::InvoiceRoutingActions::ACTIONS, Aim::InvoiceSplitActions::ACTIONS).freeze

    # These ask why, and the reason is kept: in Notes, and on the history.
    # The value is the button's label, for the refusal without one.
    REASON_ACTIONS = { 'reject' => 'Reject', 'delete' => 'Delete', 'send_back' => 'Send Back',
                       'send_to_queue' => 'Send to a queue', 'return_to_first' => 'Return to first approver' }.freeze

    private

    def invoice_action = params[:invoice_action].to_s

    def perform(name)
      action = ACTIONS[name.to_s]
      return redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue), alert: 'Unknown action.' if action.nil?
      return refuse_without_reason(REASON_ACTIONS.fetch(name.to_s)) if REASON_ACTIONS.key?(name.to_s) && reason.blank?

      send(action)
    end

    def save_only
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue), notice: 'Changes saved.'
    end

    # An invoice nobody has typed, or with no vendor or number, is not ready
    # for the person who has to approve it. Checked before anything moves.
    def send_to_approval
      return refuse_unready unless @invoice.ready_for_a_user?

      @invoice.transition_to!('ready_for_approval', actor: current_user_email, review_reason: nil)
      Aim::CodingLookup.run!(@invoice) unless @invoice.coded?
      finish('Invoice sent for approval.')
    end

    # Approval happens in a user's queue and nowhere else (Joshua, 2026-09-28):
    # from Action Needed the move is Send to Approval, which skips straight
    # to the queue.
    def approve
      return refuse('Approve it from its queue: send it to approval first.') unless @invoice.state == 'ready_for_approval'
      return refuse_unready unless @invoice.ready_for_a_user?
      return refuse('Pick or enter the coding first.') if coding_unpicked?
      return second_approval_first if @invoice.needs_second_approval?(current_user_employee_id)
      if @invoice.awaiting_second_approval? && !@invoice.second_approver?(current_user_employee_id, staff: staff?)
        return refuse("This is waiting for #{@invoice.second_approval_setting&.second_approver_name}'s second approval.")
      end

      @invoice.request_export!(actor: current_user_email)
      Aim::StampApprovedJob.perform_later(@invoice.id)
      finish('Invoice approved. It is on its way to billing and Fiscal.')
    end

    # Back to Action Needed as "Sent back" (#160): the reason shows on a red
    # banner at the top of the invoice and in its history, not in its notes.
    def send_back
      @invoice.transition_to!('needs_review', actor: current_user_email, note: "reason: #{reason}",
                                              review_reason: 'sent_back', review_note: reason)
      finish('Invoice sent back to AIM review.')
    end

    def retry_ai
      @invoice.request_extract!(actor: current_user_email)
      finish('Invoice sent back through extraction.')
    end

    def retry_export
      @invoice.request_export!(actor: current_user_email, note: 'export retried')
      finish('Export requested again.')
    end

    def reject
      folder = rejected_folder(@invoice)
      copied = keep_copy(folder)
      @invoice.transition_to!('rejected', actor: current_user_email, notes: notes_with('Rejected'),
                                          note: "reason: #{reason}; #{copied ? "copy in #{File.basename(folder)}" : 'no PDF to copy'}")
      finish('Invoice rejected. A copy is in the rejected folder for the submitter.')
    end

    # Deleting is AIM Admins' alone; the button is theirs, and so is the action.
    def delete_invoice
      return refuse('Only AIM Admins delete invoices.') unless staff?

      copied = keep_copy(File.join(Aim::InvoiceDirectoryService.instance.deleted_dir, @invoice.batch_id))
      @invoice.transition_to!('deleted', actor: current_user_email, notes: notes_with('Deleted'),
                                         note: "reason: #{reason}; #{copied ? 'copy kept in the deleted folder' : 'no PDF to copy'}")
      finish('Invoice deleted. A copy is kept in the deleted folder.')
    end

    def learn_and_retry
      learn_alias
      retry_ai
    end

    def learn_and_send
      learn_alias
      send_to_approval
    end

    def learn_alias
      normalized = params[:normalized_vendor_new].presence || params[:normalized_vendor].presence
      extracted = params[:alias_extracted].presence || @invoice.extracted_vendor_name.presence || @invoice.vendor_name
      Aim::VendorAlias.learn!(extracted_name: extracted, normalized_name: normalized,
                              learned_by: current_user_email, note: "learned on #{@invoice.batch_id}")
      @invoice.update!(vendor_name: normalized.to_s.squish)
    end

    def refuse_unready
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue),
                  alert: "This invoice still needs #{@invoice.missing_for_a_user.to_sentence}. Fill that in first."
    end

    # The reason given. Reject offers a list (#131): "Other" is the typed
    # reason; any other pick is kept with the detail typed beside it.
    def reason
      picked = params[:reason].to_s.squish
      typed = params[:reason_other].to_s.squish
      return typed if picked == Aim::RejectReason::OTHER

      [picked.presence, (typed.presence if picked.present?)].compact.join(' — ')
    end

    def refuse(message) = redirect_to(aim_invoice_path(@invoice.batch_id, queue: @queue), alert: message)

    def refuse_without_reason(label)
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue), alert: "#{label} needs a reason."
    end

    # The invoice's notes with one line added: when, what, who, and why.
    def notes_with(verb)
      line = "#{Time.zone.now.strftime('%Y-%m-%d %H:%M')} #{verb} by #{current_user_name || current_user_email}: #{reason}"
      [@invoice.notes.presence, line].compact.join("\n")
    end

    # The invoice has left this person's hands.
    def finish(notice)
      @invoice.release_claim!
      redirect_to queue_return_path, notice: notice
    end

    # A copy of the PDF for the people who look in that folder today, or nil
    # when the PDF is not in the store -- which the event then says.
    def keep_copy(folder, invoice = @invoice)
      return unless File.file?(invoice.pdf_path)

      FileUtils.mkdir_p(folder)
      copy = File.join(folder, "#{invoice.batch_id}.pdf")
      FileUtils.cp(invoice.pdf_path, copy)
      copy
    end

    # Where a rejected invoice's PDF is copied for its submitter.
    def rejected_folder(invoice)
      File.join(Aim::InvoiceDirectoryService.instance.rejected_dir,
                "#{invoice.submitter.presence || 'Unknown'}_#{invoice.budget_unit.presence || 'Unknown'}")
    end
  end
end
