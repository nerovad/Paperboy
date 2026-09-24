# frozen_string_literal: true

require 'fileutils'
require 'rexml/document'
require 'rexml/formatters/pretty'

module Aim
  class InvoicesController < BaseController
    include Aim::InvoiceQueueSupport

    helper_method :deletable_queue?

    before_action :require_aim_admin
    before_action :set_queue
    # Everything below #show rewrites or moves the invoice folder, so it needs
    # the claim. The queue list already offers a second reviewer nothing but a
    # View Only link; this is what makes that true of a posted form as well.
    before_action :require_own_claim, only: %i[update retry move_to_action_needed]

    # Every action below writes to the queue share. When it is read-only or
    # unreachable, send staff back to the queue with an explanation instead of
    # a stack trace. #show handles its own failure so the invoice stays
    # readable.
    rescue_from(*Aim::InvoiceFileSupport::WRITE_FAILURES, with: :queue_not_writable)

    def index
      dir_svc = Aim::InvoiceDirectoryService.instance

      @base_path = dir_svc.path_for(@queue)
      @queue_status = aim_queue_directory_status(@base_path)
      @queue_connected = @queue_status[:connected]
      @invoices = []

      load_invoices if @queue_connected

      @invoices.sort_by! { |invoice| invoice[:name] }
    end

    def show
      set_invoice_context
      return redirect_to aim_invoices_path(queue: @queue), alert: 'Document not found.' unless @folder_path&.then { Dir.exist?(_1) }

      prepare_review
    end

    def update
      set_invoice_context
      return redirect_to aim_invoices_path(queue: @queue), alert: 'Document not found.' unless @folder_path&.then { Dir.exist?(_1) }

      metadata_path = metadata_path_for(@folder_path) || File.join(@folder_path, "#{@invoice_id}.json")

      if params[:commit] == 'Unclaim'
        unclaim_invoice(@folder_path)
        return redirect_to aim_invoices_path(queue: @queue), notice: 'Invoice successfully unclaimed.'
      end

      metadata_params = writable_metadata_params
      write_metadata(metadata_path, metadata_params) if metadata_params.present?
      settle_document_type_from(metadata_params)

      case params[:commit]
      when 'Reject'
        reject_invoice
      when 'Delete'
        delete_invoice
      when 'Save & Learn Alias', 'Learn Alias', 'Learn & Retry AI'
        send_to_alias_learning(next_action: 'retry_ai', metadata_path: metadata_path)
      when 'Learn & Continue'
        send_to_alias_learning(next_action: 'continue_processing', metadata_path: metadata_path)
      when 'Save & Send to Approval', 'Send to Approval'
        send_to_user_approval
      when 'Send to SQL Queue'
        send_to_sql_queue
      when 'Approve Split'
        approve_split
      when 'Process as One Invoice'
        process_as_one_invoice
      else
        redirect_to aim_invoice_path(@invoice_id, queue: @queue), notice: 'Metadata saved.'
      end
    end

    def pdf
      set_invoice_context
      return head :not_found unless @folder_path&.then { Dir.exist?(_1) }

      pdf_file = pdf_files_for(@folder_path).first
      return head :not_found if pdf_file.blank?

      send_file File.join(@folder_path, pdf_file), type: 'application/pdf', disposition: 'inline'
    end

    def retry
      set_invoice_context
      return redirect_to aim_invoices_path(queue: @queue), alert: 'Document not found.' unless @folder_path&.then { Dir.exist?(_1) }

      pdf_file = pdf_files_for(@folder_path).first
      return redirect_to aim_invoice_path(@invoice_id, queue: @queue), alert: 'PDF not found.' if pdf_file.blank?

      unclaim_invoice(@folder_path)

      reprocess_dir = Aim::InvoiceDirectoryService.instance.reprocess_dir
      return redirect_to aim_invoice_path(@invoice_id, queue: @queue), alert: 'Reprocess queue is not configured.' if reprocess_dir.blank?

      FileUtils.mkdir_p(reprocess_dir)
      new_folder_name = "#{@invoice_id}_RETRY_#{Time.zone.now.to_i}"
      new_folder_path = File.join(reprocess_dir, new_folder_name)
      FileUtils.mkdir_p(new_folder_path)
      FileUtils.cp(File.join(@folder_path, pdf_file), File.join(new_folder_path, "#{new_folder_name}.pdf"))
      # Only the PDF used to make the trip, so the worker had nothing to read
      # the Budget Unit off and filed the retry under "Unknown". Step 3.2.
      write_reprocess_sidecar(File.join(new_folder_path, "#{new_folder_name}.json"),
                              read_metadata(metadata_path_for(@folder_path)))
      move_to_deleted(@folder_path)
      record_move('deleted', note: "sent back for AI retry as #{new_folder_name}")

      redirect_to aim_invoices_path(queue: @queue), notice: 'Document sent back to Reprocess Queue for AI retry.'
    end

    def move_to_action_needed
      set_invoice_context
      return redirect_to aim_invoices_path(queue: @queue), alert: 'Document not found.' unless @folder_path&.then { Dir.exist?(_1) }

      move_invoice_to(Aim::InvoiceDirectoryService.instance.action_needed_dir, 'Moved document to Action Needed Queue.',
                      state: 'action_needed')
    end

    private

    def require_own_claim
      set_invoice_context
      return unless @folder_path && Dir.exist?(@folder_path)
      return unless claimed_by_other?(@folder_path)

      redirect_to aim_invoices_path(queue: @queue),
                  alert: "#{claimant_label_for(@folder_path)} has this invoice claimed, so it is view only."
    end
  end
end
