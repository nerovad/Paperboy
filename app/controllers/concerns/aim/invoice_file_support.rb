# frozen_string_literal: true

module Aim
  module InvoiceFileSupport
    extend ActiveSupport::Concern

    private

    def claim_invoice
      claim_path = File.join(@folder_path, '.claim.json')
      return if File.exist?(claim_path)

      File.write(claim_path, { user: current_user_email, timestamp: Time.zone.now.to_i }.to_json)
    end

    def unclaim_invoice(folder_path)
      FileUtils.rm_f(File.join(folder_path, '.claim.json'))
    end

    def claimed_by_for(folder_path)
      claim_path = File.join(folder_path, '.claim.json')
      return unless File.exist?(claim_path)

      claim_data = JSON.parse(File.read(claim_path))
      claim_data['user'] || claim_data['employee_id'] || 'Someone'
    rescue JSON::ParserError
      'Unknown'
    end

    def current_user_email
      session.dig(:user, 'email') || session.dig('user', 'email') || 'Unknown User'
    end

    def reject_invoice
      unclaim_invoice(@folder_path)

      submitter = metadata_param_value('Submitter', 'Submitted by') || 'Unknown'
      budget_unit = metadata_param_value('BU', 'BudgetUnit', 'Budget Unit Number') || 'Unknown'
      reject_dir = File.join(Aim::InvoiceDirectoryService.instance.rejected_dir.to_s, "#{submitter}_#{budget_unit}")

      FileUtils.mkdir_p(reject_dir)
      FileUtils.mv(@folder_path, File.join(reject_dir, @invoice_id))

      redirect_to aim_invoices_path(queue: @queue), notice: "Invoice rejected and moved to #{submitter}_#{budget_unit} folder."
    end

    def send_to_alias_learning(next_action:, metadata_path:)
      existing_learn_data = read_vendor_learn_data(@folder_path)
      current_metadata = read_metadata(metadata_path)
      extracted_name = vendor_review_extracted_name(current_metadata, existing_learn_data)
      normalized_name = params[:normalized_vendor_new].presence ||
                        metadata_param_value('NormalizedVendor') ||
                        existing_learn_data['suggested_normalized_name']

      Aim::VendorAliasService.learn!(
        extracted_name: extracted_name,
        normalized_name: normalized_name,
        learned_by: current_user_email
      )

      learn_data = {
        'extracted_name' => extracted_name,
        'suggested_normalized_name' => normalized_name,
        'next_action' => next_action
      }
      File.write(File.join(@folder_path, "#{@invoice_id}_LEARN.json"), JSON.pretty_generate(learn_data))
      if next_action == 'continue_processing'
        write_vendor_review_ready_payload(metadata_path, current_metadata, extracted_name, normalized_name)
      elsif next_action == 'retry_ai'
        write_vendor_review_reprocess_sidecar(metadata_path, current_metadata)
      end

      move_invoice_to(Aim::InvoiceDirectoryService.instance.ready_to_learn_dir, 'Vendor Alias sent to Learner Queue.')
    rescue ArgumentError => e
      redirect_to aim_invoice_path(@invoice_id, queue: @queue), alert: e.message
    rescue Aim::VendorAliasService::AliasStoreError => e
      Rails.logger.error "Failed to save AIM vendor alias: #{e.message}"
      redirect_to aim_invoice_path(@invoice_id, queue: @queue), alert: 'Vendor alias could not be saved to the alias file.'
    end

    def writable_metadata_params
      return {} if params[:metadata].blank?

      params[:metadata].to_unsafe_h.tap do |metadata|
        next unless @queue == 'vendor_review'

        Aim::InvoicesHelper::VENDOR_REVIEW_PROTECTED_FIELDS.each { |field| metadata.delete(field) }
      end
    end

    def vendor_review_extracted_name(metadata, learn_data)
      learn_data['extracted_name'].presence ||
        metadata['ExtractedVendorName'].presence ||
        metadata['extracted_vendor_name'].presence ||
        metadata['VendorName'].presence ||
        metadata['Vendor Name'].presence
    end

    def write_vendor_review_ready_payload(metadata_path, metadata, extracted_name, normalized_name)
      payload = Aim::VendorReviewPayloadService.sql_ready_payload(
        invoice_id: @invoice_id,
        pdf_file: pdf_files_for(@folder_path).first,
        metadata: metadata,
        extracted_name: extracted_name,
        normalized_name: normalized_name
      )
      ready_path = File.join(@folder_path, "#{@invoice_id}_READY_FOR_SQL.json")

      File.write(ready_path, JSON.pretty_generate(payload))
      FileUtils.rm_f(metadata_path) if metadata_path.present? && File.expand_path(metadata_path) != File.expand_path(ready_path)
    end

    def write_vendor_review_reprocess_sidecar(metadata_path, metadata)
      metadata['bu'] ||= metadata['BU']
      metadata['submitter'] ||= metadata['Submitter']
      File.write(metadata_path, JSON.pretty_generate(metadata))
    end

    def move_invoice_to(destination_dir, notice)
      return redirect_to aim_invoice_path(@invoice_id, queue: @queue), alert: 'Destination queue is not configured.' if destination_dir.blank?

      unclaim_invoice(@folder_path)
      FileUtils.mkdir_p(destination_dir)
      FileUtils.mv(@folder_path, File.join(destination_dir, @invoice_id))

      redirect_to aim_invoices_path(queue: @queue), notice: notice
    end

    def move_to_deleted(folder_path)
      deleted_dir = Aim::InvoiceDirectoryService.instance.deleted_dir
      return FileUtils.rm_rf(folder_path) if deleted_dir.blank?

      FileUtils.mkdir_p(deleted_dir)
      FileUtils.mv(folder_path, File.join(deleted_dir, File.basename(folder_path)))
    end

    def safe_invoice_id(raw_id)
      invoice_id = raw_id.to_s
      return if invoice_id.blank?
      return if invoice_id.include?('/') || invoice_id.include?('\\')
      return if ['.', '..'].include?(invoice_id)

      invoice_id
    end

    def invoice_folder_path(base_path, invoice_id)
      return if base_path.blank? || invoice_id.blank?

      base = File.expand_path(base_path.to_s)
      folder_path = File.expand_path(File.join(base, invoice_id))
      return unless folder_path.start_with?("#{base}#{File::SEPARATOR}")

      folder_path
    end

    def metadata_param_value(*keys)
      metadata = params[:metadata] || {}

      keys.each do |key|
        value = metadata[key]
        return value if value.present?
      end

      nil
    end
  end
end
