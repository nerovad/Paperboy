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

    def send_to_alias_learning
      unclaim_invoice(@folder_path)

      learn_data = {
        'extracted_name' => params.dig(:metadata, 'VendorName'),
        'suggested_normalized_name' => params.dig(:metadata, 'NormalizedVendor') || params.dig(:metadata, 'VendorName')
      }
      File.write(File.join(@folder_path, "#{@invoice_id}_LEARN.json"), JSON.pretty_generate(learn_data))

      move_invoice_to(Aim::InvoiceDirectoryService.instance.ready_to_learn_dir, 'Vendor Alias sent to Learner Queue.')
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
