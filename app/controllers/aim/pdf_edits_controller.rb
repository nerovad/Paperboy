# frozen_string_literal: true

module Aim
  # Edit PDF (#181, #182): swap an invoice's PDF for an uploaded one, apply
  # the page editor's plan, or restore a version -- each a new version, at
  # once, in Rails (Aim::PdfVersions). The editor reads the current version's
  # base and inserted PDFs and its plan, so its text boxes stay editable.
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

    # The current version's base PDF, or its +n+th inserted PDF: what the
    # editor lays its plan over. Never the approval-stamped copy.
    def source
      version = Aim::PdfVersions.current(@invoice)
      path = if params[:insert].present? then version&.insert_paths&.dig(params[:insert].to_i - 1)
             else version&.base_path || store_file(@invoice, 'pdf')
             end
      return head :not_found unless path && File.file?(path) && File.dirname(path) == @invoice.store_dir

      send_file path, type: 'application/pdf', disposition: 'inline', filename: File.basename(path)
    end

    # Version +number+ as it looked, rendered for viewing.
    def version
      version = Aim::PdfVersions.all(@invoice).find_by(number: params[:number].to_i)
      return head :not_found if version.nil?

      Tempfile.create(['aim-version', '.pdf']) do |out|
        Aim::PdfVersions.render_to(version, out.path)
        send_data File.binread(out.path), type: 'application/pdf', disposition: 'inline',
                                          filename: "#{@invoice.handle} version #{version.number}.pdf"
      end
    rescue Aim::PdfEdit::Unreadable
      head :unprocessable_content
    end

    def replace
      file = params[:file]
      return back_to_editor(alert: 'Choose a PDF to swap in.') unless file.respond_to?(:path)

      Aim::PdfVersions.swap!(@invoice, file.path, name: file.original_filename.to_s.truncate(120), actor: current_user_email)
      finish('PDF swapped.')
    rescue Aim::PdfVersions::Refused => e
      back_to_editor(alert: e.message)
    end

    def update
      pages = JSON.parse(params[:pages].to_s)
      uploads = Array(params[:inserts]).first(MAX_INSERTS).select { |file| file.respond_to?(:path) }
      Aim::PdfVersions.edit!(@invoice, pages, uploads.map { |file| [file.path, file.original_filename.to_s] }, actor: current_user_email)
      finish('PDF changes applied.')
    rescue JSON::ParserError, Aim::PdfVersions::Refused => e
      back_to_editor(alert: "Not applied: #{e.message}. Nothing has changed.")
    end

    def restore
      Aim::PdfVersions.restore!(@invoice, params[:number].to_i, actor: current_user_email)
      finish("Version #{params[:number].to_i} restored, as a new version.")
    rescue Aim::PdfVersions::Refused => e
      back_to_editor(alert: e.message)
    end

    private

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
