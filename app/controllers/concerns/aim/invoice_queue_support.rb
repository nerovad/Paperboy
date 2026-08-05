# frozen_string_literal: true

module Aim
  module InvoiceQueueSupport
    extend ActiveSupport::Concern
    include Aim::InvoiceFileSupport
    include Aim::InvoiceXmlMetadataSupport

    private

    def set_queue
      @queue = params[:queue].presence || 'action_needed'
      return if Aim::InvoiceDirectoryService::BACKEND_QUEUES.key?(@queue.to_sym)

      redirect_to aim_root_path, alert: 'Unknown AIM queue.'
    end

    def load_invoices
      Dir.glob(File.join(@base_path.to_s, '*')).each do |folder_path|
        next unless File.directory?(folder_path)

        @invoices << invoice_summary(folder_path)
      end
    end

    def invoice_summary(folder_path)
      invoice_name = File.basename(folder_path)
      metadata_path = metadata_path_for(folder_path)
      metadata = read_metadata(metadata_path)
      pdf_files = pdf_files_for(folder_path)
      claimed_by = claimed_by_for(folder_path)

      {
        id: invoice_name,
        name: invoice_name,
        path: folder_path,
        metadata: metadata,
        pdf_file: pdf_files.first,
        status_text: queue_item_status(metadata_path, metadata, pdf_files),
        status_badge: queue_item_status_badge(metadata_path, metadata, pdf_files),
        reviewable: @queue != 'ai_queue',
        claimed_by: claimed_by,
        is_locked: claimed_by.present? && claimed_by != current_user_email
      }
    end

    def set_invoice_context
      @invoice_id = safe_invoice_id(params[:id])
      @base_path = Aim::InvoiceDirectoryService.instance.path_for(@queue)
      @folder_path = invoice_folder_path(@base_path, @invoice_id)
    end

    def metadata_path_for(folder_path)
      children = Dir.children(folder_path)

      if @queue == 'ai_queue'
        ticket_path = File.join(folder_path, 'job_ticket.json')
        return ticket_path if File.exist?(ticket_path)
      end

      if @queue == 'low_confidence_review'
        xml_files = children.select { |file_name| file_name.downcase.end_with?('.xml') }
        return File.join(folder_path, xml_files.first) if xml_files.any?
      end

      json_files = children.select do |file_name|
        file_name.downcase.end_with?('.json') && !file_name.include?('_LEARN') && file_name != '.claim.json'
      end
      json_files.any? ? File.join(folder_path, json_files.first) : nil
    end

    def read_metadata(metadata_path)
      return {} unless metadata_path && File.exist?(metadata_path)

      if metadata_path.downcase.end_with?('.xml')
        read_xml_metadata(metadata_path)
      else
        JSON.parse(File.read(metadata_path))
      end
    rescue JSON::ParserError, REXML::ParseException
      { 'error' => 'Invalid metadata' }
    end

    def load_vendor_review_context
      @vendor_learn_data = read_vendor_learn_data(@folder_path)
      @official_vendor_names = official_vendor_names
      @metadata['VendorName'] ||= @vendor_learn_data['extracted_name']
      @metadata['NormalizedVendor'] ||= @vendor_learn_data['suggested_normalized_name']
    end

    def read_vendor_learn_data(folder_path)
      learn_file = Dir.children(folder_path).find { |file_name| file_name.end_with?('_LEARN.json') }
      return {} if learn_file.blank?

      JSON.parse(File.read(File.join(folder_path, learn_file)))
    rescue JSON::ParserError
      {}
    end

    def official_vendor_names
      Aim::VendorAliasService.official_names
    rescue Aim::VendorAliasService::AliasStoreError => e
      Rails.logger.warn "Failed to load AIM vendor aliases: #{e.message}"
      []
    end

    def write_metadata(metadata_path, metadata_params)
      if metadata_path.downcase.end_with?('.xml')
        write_xml_metadata(metadata_path, metadata_params)
      else
        metadata = File.exist?(metadata_path) ? JSON.parse(File.read(metadata_path)) : {}
        metadata_params.each { |key, value| metadata[key] = value }
        File.write(metadata_path, JSON.pretty_generate(metadata))
      end
    end

    def pdf_files_for(folder_path)
      Dir.children(folder_path).select { |file_name| file_name.downcase.end_with?('.pdf') }
    end

    def ticket_content_for(folder_path)
      ticket_file = Dir.children(folder_path).find { |file_name| file_name.downcase.end_with?('.ticket') }
      return if ticket_file.blank?

      File.read(File.join(folder_path, ticket_file))
    end

    def queue_item_status(metadata_path, metadata, pdf_files)
      return metadata['Status'].presence || 'Ready' unless @queue == 'ai_queue'
      return 'Missing PDF' if pdf_files.empty?
      return 'Missing ticket' if metadata_path.blank?
      return 'Invalid ticket' if metadata['error'].present?
      return 'Urgent' if ActiveModel::Type::Boolean.new.cast(metadata['is_urgent'])

      'Waiting for AI'
    end

    def queue_item_status_badge(metadata_path, metadata, pdf_files)
      return 'is-denied' if @queue == 'ai_queue' && (pdf_files.empty? || metadata_path.blank? || metadata['error'].present?)
      return 'is-in-review' if @queue == 'ai_queue' && ActiveModel::Type::Boolean.new.cast(metadata['is_urgent'])
      return 'is-pending' if @queue == 'ai_queue'

      nil
    end
  end
end
