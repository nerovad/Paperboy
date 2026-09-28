# frozen_string_literal: true

module Aim
  # The queues and the review page, over rows. AIM v2: every button is a move
  # of the row's state, refused with a message when the pipeline does not make
  # it; the PDF is read from the store and never moved.
  class InvoicesController < BaseController
    include Aim::InvoiceActions
    include Aim::InvoiceAccess
    include Aim::InvoiceLocking
    include Aim::InvoiceBulkMoves
    include Aim::InvoiceRestore
    include Aim::StoredPdf

    before_action :require_aim_admin, :remember_queue_page, only: :index
    before_action :set_queue
    before_action :set_invoice, only: %i[show update pdf reassign lock unlock claim restore code]
    before_action :require_staff_or_owner, only: %i[show update pdf reassign lock unlock claim restore code]
    # Everything #update does changes the invoice, so it needs the claim. The
    # queue list already offers a second reviewer nothing but View Only; this
    # is what makes that true of a posted form as well.
    before_action :require_editor, only: :update

    def index
      @review_reason = params[:review_reason].presence if @queue == 'needs_review'
      scope = Aim::Invoice.in_queue(@queue).newest_first
      scope = scope.where(review_reason: @review_reason) if @review_reason
      @invoices = scope.to_a
      @reason_counts = @queue == 'needs_review' ? Aim::Invoice.in_queue(@queue).group(:review_reason).count : {}
      # Budget unit -> shared queue and each person -> invoices, as on By BU.
      @sections = Aim::BuSections.build(@invoices, coa: Aim::Units.new) if @queue == 'ready_for_approval'
    rescue ActiveRecord::ActiveRecordError => e
      Rails.logger.error "AIM could not list the #{@queue} queue: #{e.message}"
      @invoices = []
      @reason_counts = {}
      flash.now[:alert] = 'The invoice database could not be read.'
    end

    def show
      prepare_review
    end

    def update
      if params[:commit] == 'Unclaim'
        @invoice.release_claim!
        return redirect_to aim_invoices_path(queue: @queue), notice: 'Invoice unclaimed.'
      end

      save_fields
      perform(params[:commit])
    rescue Aim::Invoice::IllegalTransition, ActiveRecord::RecordInvalid, ArgumentError => e
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue), alert: e.message
    rescue Aim::MissingConfiguration, SystemCallError => e
      Rails.logger.error "AIM file write failed for #{@invoice.batch_id.inspect}: #{e.class}: #{e.message}"
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue),
                  alert: 'That did not go through: the AIM file share could not be reached. Try again.'
    end

    # A person picks one of several matching coding rules (item b.2).
    def code
      rule = Aim::CodingRule.find_by(id: params[:coding_rule_id])
      candidates = Aim::CodingLookup.candidates(@invoice)&.last || []
      return redirect_to(aim_invoice_path(@invoice.batch_id, queue: @queue), alert: 'Pick one of the coding rules shown.') unless rule && candidates.include?(rule)

      Aim::CodingLookup.choose!(@invoice, rule, by: current_user_email)
      redirect_to aim_invoice_path(@invoice.batch_id, queue: @queue), notice: 'Coding set.'
    end

    def pdf
      path = stored_pdf_path
      return head :not_found if path.nil?

      # Once approved, an invoice goes by Fiscal's name for it (item f).
      name = Aim::FiscalRecord::APPROVED_STATES.include?(@invoice.state) ? Aim::FiscalRecord.file_name_for(@invoice) : "#{@invoice.batch_id}.pdf"
      send_file path, type: 'application/pdf', disposition: 'inline', filename: name
    end

    private

    def set_queue
      @queue = params[:queue].presence || 'needs_review'
      return if Aim::Invoice::QUEUES.key?(@queue)

      redirect_to aim_root_path, alert: 'Unknown AIM queue.'
    end

    def set_invoice
      @invoice = Aim::Invoice.find_by(batch_id: params[:id].to_s)
      return if @invoice

      redirect_to aim_invoices_path(queue: @queue), alert: 'Invoice not found.'
    end

    # Opening a review page takes the working lock only when you may work the
    # invoice and nobody else is in it; otherwise it is read only. Looking
    # never locks anything.
    def prepare_review
      @claimed_by_other = @invoice.claimed_by_other?(current_user_email)
      @editor = editor?
      @invoice.claim!(current_user_email, name: current_user_name) if @editor && !@claimed_by_other
      @read_only = !@editor || @claimed_by_other
      @claimable = claimable?
      @claim_holder = helpers.aim_claimant_label(@invoice)
      @pdf_present = pdf_present?
      @events = @invoice.events.to_a
      @official_vendor_names = Aim::VendorAlias.official_names
      load_split_context if @invoice.state == 'needs_split'
      prepare_coding
    end

    # The invoice's coding, or the rules to choose from (item b.2).
    def prepare_coding
      Aim::CodingLookup.ensure!(@invoice)
      @coding_lines = @invoice.coding_lines.to_a
      return if @coding_lines.any? || !@invoice.coded?

      @coding_level, @coding_candidates = Aim::CodingLookup.candidates(@invoice)
      return if @coding_candidates.blank?

      @coding_differing = Aim::CodingLookup.differing_fields(@coding_candidates)
      @coding_hinted = Aim::CodingLookup.hinted(@coding_candidates, stored_pdf_path)
    end

    def pdf_present? = stored_pdf_path.present?

    def save_fields
      permitted = params.fetch(:invoice, {}).permit(*Aim::Invoice::EDITABLE_FIELDS).to_h
      return if permitted.empty?

      @invoice.update!(permitted.transform_values { |value| value.is_a?(String) ? value.strip.presence : value })
      forget_coding_if_rematch_needed
    end

    # A new vendor, BU or customer number may match other rules.
    def forget_coding_if_rematch_needed
      changed = @invoice.previous_changes.keys & %w[vendor_name budget_unit customer_number]
      return if changed.empty?

      @invoice.update_column(:agency, nil) if changed.include?('budget_unit')
      @invoice.forget_rule_coding!
    end
  end
end
