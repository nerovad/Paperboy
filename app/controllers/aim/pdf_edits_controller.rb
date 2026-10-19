# frozen_string_literal: true

module Aim
  # Edit PDF (#181): swap an invoice's PDF for an uploaded one, or apply the
  # page editor's changes, at once, in Rails (Aim::PdfEdit, Aim::PdfVersions).
  # AIM staff while it is being worked (not if someone else is in it), and
  # Fiscal on invoices of their groups that are with them; never while the AI
  # or the export has it, nor once it is finished elsewhere or archived.
  class PdfEditsController < BaseController
    include Aim::StoredPdf

    MAX_INSERTS = 5

    before_action :set_invoice
    before_action :require_pdf_editor

    # The editor lives in the review and Fiscal pages' Document panel now.
    def show = redirect_to(return_path)

    # The PDF as received (never the approval-stamped copy): what the editor
    # works on.
    def source
      path = store_file(@invoice, 'pdf')
      return head :not_found if path.nil?

      send_file path, type: 'application/pdf', disposition: 'inline', filename: "#{@invoice.batch_id}.pdf"
    end

    def replace
      file = params[:file]
      return back_to_editor(alert: 'Choose a PDF to swap in.') unless file.respond_to?(:path)

      name = file.original_filename.to_s.truncate(120)
      Aim::PdfVersions.replace!(@invoice, file.path, actor: current_user_email, name: name, note: "PDF swapped for #{name}")
      finish('PDF swapped.')
    rescue Aim::PdfVersions::Refused => e
      back_to_editor(alert: e.message)
    end

    def update
      pages = JSON.parse(params[:pages].to_s)
      inserts = Array(params[:inserts]).first(MAX_INSERTS).select { |file| file.respond_to?(:path) }
      inserts.each { |file| Aim::PdfVersions.check!(file.path, name: file.original_filename) }
      Tempfile.create(['aim-edit', '.pdf']) do |out|
        Aim::PdfEdit.new(@invoice.pdf_path, inserts: inserts.map(&:path)).write(out.path, pages)
        Aim::PdfVersions.replace!(@invoice, out.path, actor: current_user_email,
                                                      note: "PDF edited: #{summary(pages, inserts)}")
      end
      finish('PDF changes applied.')
    rescue JSON::ParserError, Aim::PdfEdit::Unreadable, Aim::PdfVersions::Refused => e
      back_to_editor(alert: "Not applied: #{e.message}. Nothing has changed.")
    end

    private

    def summary(pages, inserts)
      Aim::PdfEditSummary.new(pages, inserts.map(&:original_filename), original_count: @invoice.page_count).to_s
    end

    def set_invoice
      @invoice = Aim::Invoice.find_by(batch_id: params[:id].to_s)
      redirect_to aim_root_path, alert: 'Invoice not found.' if @invoice.nil?
    end

    def require_pdf_editor
      return if Aim::PdfVersions.editable?(@invoice) && (staff_editor? || fiscal_editor?)

      redirect_to return_path, alert: 'This invoice\'s PDF cannot be changed here.'
    end

    def staff_editor? = helpers.aim_queue_access? && !@invoice.claimed_by_other?(current_user_email)

    def fiscal_editor?
      Aim::FiscalRecord.exists?(invoice_id: @invoice.id) && helpers.aim_fiscal? &&
        helpers.aim_agency_groups.serves?(helpers.aim_fiscal_reach, @invoice)
    end

    # Back where the person came from: Fiscal's page for Fiscal, else the
    # review page in the invoice's queue.
    def return_path
      return aim_fiscal_invoice_path(@invoice.batch_id) if params[:from] == 'fiscal'

      aim_invoice_path(@invoice.batch_id, queue: @invoice.queue)
    end
    helper_method :return_path

    def back_to_editor(alert:) = redirect_to(return_path, alert: alert)

    # Read it again with the AI, when asked and the pipeline allows it.
    def finish(notice)
      if params[:reread] == '1' && @invoice.can_move_to?('received')
        @invoice.request_extract!(actor: current_user_email, note: 'read again after the PDF changed')
        notice += ' Sent back to the AI to read again.'
      end
      redirect_to return_path, notice: notice
    end
  end
end
