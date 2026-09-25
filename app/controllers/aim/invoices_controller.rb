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

    before_action :require_aim_admin, :remember_queue_page, only: :index
    before_action :set_queue
    before_action :set_invoice, only: %i[show update pdf reassign lock unlock claim restore]
    before_action :require_staff_or_owner, only: %i[show update pdf reassign lock unlock claim restore]
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
      group_by_owner if @queue == 'ready_for_approval'
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
                  alert: 'The AIM share could not be written to, so that action did not complete. Check the share and try again.'
    end

    def pdf
      path = stored_pdf_path
      return head :not_found if path.nil?

      send_file path, type: 'application/pdf', disposition: 'inline'
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
    end

    def pdf_present? = stored_pdf_path.present?

    # Ready for Approval is people's queues: one group per owner, the shared
    # queue last, each with the queues an invoice of that BU can move to.
    def group_by_owner
      @groups = @invoices.group_by { |invoice| owner_group(invoice) }
                         .sort_by { |(shared, name), _| [shared ? 1 : 0, name.downcase] }
    end

    # One group per person, and one shared queue per BU.
    def owner_group(invoice)
      return [true, "#{invoice.budget_unit} shared queue"] if invoice.assigned_employee_id.nil?

      [false, invoice.assigned_to.presence || "Employee #{invoice.assigned_employee_id}"]
    end

    # The store, then the invoice's folder, then its PDF, and nothing from the
    # row may name a file outside the store: the batch id has to be one path
    # component, and the resolved path has to stay under the store.
    def stored_pdf_path
      store = File.expand_path(Aim::InvoiceDirectoryService.instance.store_dir)
      name = @invoice.batch_id.to_s
      return if name.blank? || name.match?(%r{[/\\]}) || name.start_with?('.')

      path = File.expand_path(File.join(store, name, "#{name}.pdf"))
      path if path.start_with?("#{store}/") && File.file?(path)
    rescue Aim::MissingConfiguration
      nil
    end

    def save_fields
      permitted = params.fetch(:invoice, {}).permit(*Aim::Invoice::EDITABLE_FIELDS).to_h
      return if permitted.empty?

      @invoice.update!(permitted.transform_values { |value| value.is_a?(String) ? value.strip.presence : value })
    end
  end
end
