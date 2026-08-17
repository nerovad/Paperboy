# frozen_string_literal: true

require 'fileutils'
require 'rexml/document'
require 'rexml/formatters/pretty'

module Aim
  class InvoicesController < BaseController
    include Aim::InvoiceQueueSupport

    before_action :require_aim_admin
    before_action :set_queue

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

      # A claim that could not be written, or an already-claimed invoice whose
      # share has since gone read-only, both mean nothing here can be saved.
      @read_only = !claim_invoice || !File.writable?(@folder_path)

      @metadata_path = metadata_path_for(@folder_path)
      @metadata = read_metadata(@metadata_path)
      load_vendor_review_context if @queue == 'vendor_review'
      @ticket_content = ticket_content_for(@folder_path)
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

      case params[:commit]
      when 'Reject'
        reject_invoice
      when 'Save & Learn Alias', 'Learn Alias', 'Learn & Retry AI'
        send_to_alias_learning(next_action: 'retry_ai', metadata_path: metadata_path)
      when 'Learn & Continue'
        send_to_alias_learning(next_action: 'continue_processing', metadata_path: metadata_path)
      when 'Save & Send to Approval', 'Send to Approval'
        move_invoice_to(Aim::InvoiceDirectoryService.instance.user_approval_dir, 'Invoice successfully fixed and routed to User Approval!')
      when 'Send to SQL Queue'
        move_invoice_to(Aim::InvoiceDirectoryService.instance.sql_queue_dir, 'Invoice index verified and routed to SQL Queue.')
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
      move_to_deleted(@folder_path)

      redirect_to aim_invoices_path(queue: @queue), notice: 'Document sent back to Reprocess Queue for AI retry.'
    end

    def move_to_action_needed
      set_invoice_context
      return redirect_to aim_invoices_path(queue: @queue), alert: 'Document not found.' unless @folder_path&.then { Dir.exist?(_1) }

      move_invoice_to(Aim::InvoiceDirectoryService.instance.action_needed_dir, 'Moved document to Action Needed Queue.')
    end

    private

    # A move or a metadata write can fail partway through, so this promises
    # nothing about what did or did not happen on disk.
    def queue_not_writable(error)
      Rails.logger.error "AIM write failed for #{@invoice_id.inspect} in #{@queue}: #{error.class}: #{error.message}"

      redirect_to aim_invoices_path(queue: @queue),
                  alert: 'The queue folder could not be written to, so that action did not complete. ' \
                         'Check the queue share and try again.'
    end
  end
end
