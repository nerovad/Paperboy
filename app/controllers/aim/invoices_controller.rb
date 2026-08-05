# frozen_string_literal: true

require 'fileutils'
require 'rexml/document'
require 'rexml/formatters/pretty'

module Aim
  class InvoicesController < BaseController
    include Aim::InvoiceQueueSupport

    before_action :require_aim_admin
    before_action :set_queue

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

      claim_invoice

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

      write_metadata(metadata_path, params[:metadata]) if params[:metadata].present?

      case params[:commit]
      when 'Reject'
        reject_invoice
      when 'Save & Learn Alias', 'Learn Alias'
        send_to_alias_learning
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
  end
end
