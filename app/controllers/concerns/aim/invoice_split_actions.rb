# frozen_string_literal: true

module Aim
  # The review page's split moves, beside Aim::InvoiceActions (whose ACTIONS
  # name them): a split the AI asked for, or one AIM staff start by hand
  # (#192), approved and cut here in Rails (Aim::BatchSplit), or called off.
  module InvoiceSplitActions
    extend ActiveSupport::Concern

    # Added to Aim::InvoiceActions::ACTIONS.
    ACTIONS = {
      'approve_split' => :approve_split,
      'process_as_one' => :process_as_one,
      'start_split' => :start_split,
      'keep_as_one' => :keep_as_one
    }.freeze

    private

    # A person's split, checked by Aim::SplitPlan and cut at once: each
    # invoice becomes a new one for the AI to read. A refused plan, or a PDF
    # that cannot be cut, re-renders the page with what was typed and why.
    def approve_split
      plan = split_plan_from_params
      return refuse_split(plan, 'The split was not approved. Nothing has changed.') unless plan.valid?

      children = Aim::BatchSplit.new(@invoice, plan).run!(actor: current_user_email)
      finish("Split into #{children.size} invoices. The AI reads each one; they reach the queues as it does.")
    rescue Aim::BatchSplit::Failed => e
      plan.errors << "Not split: #{e.message}."
      refuse_split(plan, 'The split was not made. Nothing has changed.')
    end

    def process_as_one
      @invoice.request_extract!(actor: current_user_email, split_check: false, note: 'process as one invoice')
      finish('Sent back through extraction as one invoice.')
    end

    # Split by hand (#192): AIM staff, from Action Needed or Ready for
    # Approval. The page comes back as the split screen, still theirs.
    def start_split
      return refuse('Only AIM staff split an invoice.') unless staff?

      @invoice.start_split!(actor: current_user_email)
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @invoice.queue),
                  notice: 'Click the page each invoice starts on and press New invoice starts here, then Approve Split.'
    end

    # A split started by hand, called off: back where it was, as it was,
    # without the AI reading it again.
    def keep_as_one
      from = @invoice.split_started_from
      return refuse('The AI asked for this split: use Process as One Invoice.') if from.nil?

      @invoice.transition_to!(from, actor: current_user_email, note: 'kept as one invoice')
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @invoice.queue), notice: 'Kept as one invoice.'
    end

    def refuse_split(plan, alert)
      @split_plan = plan
      prepare_review
      flash.now[:alert] = alert
      render :show, status: :unprocessable_content
    end

    # Rows arrive as split[0][pages_text] and so on, one per invoice.
    def split_plan_from_params
      rows = params.fetch(:split, {}).to_unsafe_h.sort_by { |index, _| index.to_i }.map do |_, row|
        row.slice('vendor_name', 'invoice_number', 'pages_text')
      end
      Aim::SplitPlan.new(rows, page_count: @invoice.page_count)
    end

    # The rows the split editor shows: what the person typed if a split was
    # refused, otherwise what the AI proposed or the split by hand began with.
    def load_split_context
      @split_page_count = @invoice.page_count
      @split_by_hand = @invoice.split_started_from.present?
      @split_rows = @split_plan&.rows || Aim::SplitPlan.rows_from_manifest(@invoice.manifest_data)
    end
  end
end
