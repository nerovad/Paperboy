# frozen_string_literal: true

module Aim
  # Waiting for AI (#192), beside Aim::InvoiceActions (whose ACTIONS name the
  # review page's): AIM staff hold an invoice from the AI, release it, start
  # the AI again, or skip it to Action Needed -- one at a time, or every
  # ticked one on the Waiting for AI list (#waiting_many, with Reject and
  # Delete too). Aim::InvoiceAiControl says what the AI allows.
  module InvoiceAiActions
    extend ActiveSupport::Concern

    # Added to Aim::InvoiceActions::ACTIONS.
    ACTIONS = {
      'hold_ai' => :hold_ai,
      'release_hold' => :release_hold,
      'restart_ai' => :restart_ai,
      'skip_ai' => :skip_ai
    }.freeze

    # What the list's ticked invoices can be given, each checked on its own.
    MANY = %w[hold_ai release_hold skip_ai reject delete].freeze

    def waiting_many
      action = params[:bulk_action].to_s
      return redirect_back_or_to(aim_invoices_path(queue: 'received'), alert: 'Pick what to do.') unless MANY.include?(action)
      return redirect_back_or_to(aim_invoices_path(queue: 'received'), alert: "#{action.capitalize} needs a reason.") if %w[reject delete].include?(action) && reason.blank?

      ids = Array(params[:ids]).map(&:to_s).uniq
      invoices = helpers.aim_agency_groups.invoices(helpers.aim_managing_groups).where(batch_id: ids).to_a
      done = invoices.count { |invoice| apply_waiting(action, invoice) }
      skipped = ids.size - done
      notice = "#{WAITING_DONE.fetch(action)} #{helpers.pluralize(done, 'invoice')}." +
               (skipped.positive? ? " #{skipped} could not be: the AI had moved on or a worker that cannot be stopped has it." : '')
      redirect_back_or_to aim_invoices_path(queue: 'received'), notice: notice
    end

    WAITING_DONE = { 'hold_ai' => 'Put on hold', 'release_hold' => 'Released to the AI', 'skip_ai' => 'Sent to Action Needed',
                     'reject' => 'Rejected', 'delete' => 'Deleted' }.freeze

    private

    def hold_ai
      return refuse('Only AIM staff hold an invoice from the AI.') unless staff?

      @invoice.hold_ai!(actor: current_user_email, reason: reason.presence)
      finish('On hold: the AI leaves it until the hold is released.')
    end

    def release_hold
      return refuse('Only AIM staff release a hold.') unless staff?

      @invoice.release_hold!(actor: current_user_email)
      finish('Released: the AI reads it next.')
    end

    def restart_ai
      return refuse('Only AIM staff start the AI again.') unless staff?

      @invoice.restart_ai!(actor: current_user_email)
      finish('The AI starts this one again from the first page.')
    end

    # Stays on the page, now in Action Needed, to be typed in.
    def skip_ai
      return refuse('Only AIM staff skip the AI.') unless staff?

      @invoice.skip_ai_to_review!(actor: current_user_email)
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @invoice.queue),
                  notice: 'The AI will not read it. Type the details in from the PDF, then Send to Approval.'
    end

    # One ticked invoice; false when it could not be done.
    def apply_waiting(action, invoice)
      return false unless invoice.waiting_for_ai? && invoice.ai_stoppable?

      case action
      when 'hold_ai' then invoice.hold_ai!(actor: current_user_email)
      when 'release_hold' then invoice.release_hold!(actor: current_user_email)
      when 'skip_ai' then invoice.skip_ai_to_review!(actor: current_user_email)
      when 'reject' then reject_one(invoice)
      when 'delete' then delete_one(invoice)
      end
      true
    rescue Aim::Invoice::IllegalTransition, ActiveRecord::RecordInvalid
      false
    end

    def reject_one(invoice)
      folder = rejected_folder(invoice)
      copied = keep_copy(folder, invoice)
      invoice.transition_to!('rejected', actor: current_user_email, notes: notes_with('Rejected', invoice),
                                         note: "reason: #{reason}; #{copied ? "copy in #{File.basename(folder)}" : 'no PDF to copy'}")
    end

    def delete_one(invoice)
      copied = keep_copy(File.join(Aim::InvoiceDirectoryService.instance.deleted_dir, invoice.batch_id), invoice)
      invoice.transition_to!('deleted', actor: current_user_email, notes: notes_with('Deleted', invoice),
                                        note: "reason: #{reason}; #{copied ? 'copy kept in the deleted folder' : 'no PDF to copy'}")
    end
  end
end
