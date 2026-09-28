# frozen_string_literal: true

require 'fileutils'

module Aim
  # What each button on the review page does. Every one is a move of the row's
  # state through Aim::Invoice#transition_to!, so a move the pipeline does not
  # make is refused with its reason (the controller turns IllegalTransition
  # into an alert). The worker is asked for work by setting the row's command.
  module InvoiceActions
    extend ActiveSupport::Concern

    ACTIONS = {
      'Save Changes' => :save_only,
      'Send to Approval' => :send_to_approval,
      'Approve' => :approve,
      'Send Back' => :send_back,
      'Retry AI' => :retry_ai,
      'Approve Split' => :approve_split,
      'Process as One Invoice' => :process_as_one,
      'Reject' => :reject,
      'Delete' => :delete_invoice,
      'Learn & Retry AI' => :learn_and_retry,
      'Learn & Send to Approval' => :learn_and_send,
      'Retry Export' => :retry_export
    }.freeze

    # These ask why, and the reason is kept: in Notes, and on the history.
    REASON_ACTIONS = { 'Reject' => 'Rejected', 'Delete' => 'Deleted', 'Send Back' => 'Sent back' }.freeze

    private

    def perform(commit)
      action = ACTIONS[commit.to_s]
      return redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue), alert: 'Unknown action.' if action.nil?
      return refuse_without_reason(commit) if REASON_ACTIONS.key?(commit.to_s) && reason.blank?

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

      @invoice.request_export!(actor: current_user_email)
      Aim::StampApprovedJob.perform_later(@invoice.id)
      finish('Invoice approved. It is on its way to billing and Fiscal.')
    end

    def send_back
      @invoice.transition_to!('needs_review', actor: current_user_email, note: "reason: #{reason}",
                                              notes: notes_with('Sent back'))
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

    def process_as_one
      @invoice.request_extract!(actor: current_user_email, split_check: false, note: 'process as one invoice')
      finish('Sent back through extraction as one invoice.')
    end

    # A person's corrected split, checked by Aim::SplitPlan, saved as the
    # manifest the worker cuts by. A refused plan re-renders the page with what
    # was typed and why.
    def approve_split
      plan = split_plan_from_params
      unless plan.valid?
        @split_plan = plan
        prepare_review
        flash.now[:alert] = 'The split was not approved. Nothing has changed.'
        return render :show, status: :unprocessable_content
      end

      @invoice.request_split!(plan.manifest(@invoice.manifest_data), actor: current_user_email)
      finish("Split approved into #{plan.manifest['invoices'].size} invoices. Each appears in the queues as it is cut.")
    end

    def reject
      folder = File.join(Aim::InvoiceDirectoryService.instance.rejected_dir,
                         "#{@invoice.submitter.presence || 'Unknown'}_#{@invoice.budget_unit.presence || 'Unknown'}")
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

    def reason = params[:reason].to_s.squish

    def refuse(message) = redirect_to(aim_invoice_path(@invoice.batch_id, queue: @queue), alert: message)

    def refuse_without_reason(commit)
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue), alert: "#{commit} needs a reason."
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
    def keep_copy(folder)
      return unless File.file?(@invoice.pdf_path)

      FileUtils.mkdir_p(folder)
      copy = File.join(folder, "#{@invoice.batch_id}.pdf")
      FileUtils.cp(@invoice.pdf_path, copy)
      copy
    end

    # Rows arrive as split[0][pages_text] and so on, one per invoice.
    def split_plan_from_params
      rows = params.fetch(:split, {}).to_unsafe_h.sort_by { |index, _| index.to_i }.map do |_, row|
        row.slice('vendor_name', 'invoice_number', 'pages_text')
      end
      Aim::SplitPlan.new(rows, page_count: @invoice.page_count)
    end

    # The rows the split editor shows: what the person typed if a split was
    # refused, otherwise what the AI proposed.
    def load_split_context
      @split_page_count = @invoice.page_count
      @split_rows = @split_plan&.rows || Aim::SplitPlan.rows_from_manifest(@invoice.manifest_data)
    end
  end
end
