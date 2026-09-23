# frozen_string_literal: true

module Aim
  module InvoiceFileSupport
    extend ActiveSupport::Concern

    # The queue lives on a mounted share that can come back read-only, vanish
    # or fill up. Those failures are expected operating conditions, not bugs,
    # so callers handle them rather than letting a stack trace reach staff.
    # ENOENT belongs with them: when two reviewers hold the same invoice open
    # and one of them moves it, the other's write lands in a folder that is no
    # longer there, and the loser of that race gets the queue back rather than
    # a 500.
    WRITE_FAILURES = [Errno::EACCES, Errno::EPERM, Errno::EROFS, Errno::ENOSPC, Errno::ENOENT].freeze

    private

    # True only when this invoice is ours to work: either it was unclaimed and
    # we just claimed it, or the claim already on it is our own. A claim used
    # to count merely by existing, which handed a second reviewer the full
    # action strip on someone else's invoice. Plan step 2.1.
    #
    # Returns false when the claim could not be recorded, which leaves the
    # invoice unreserved — the review page goes read-only rather than offering
    # actions whose writes would fail too.
    def claim_invoice
      owner, = claim_details_for(@folder_path)
      return own_claim?(owner) if owner.present?

      claim = { user: current_user_email, name: current_user_name, timestamp: Time.zone.now.to_i }
      File.write(File.join(@folder_path, '.claim.json'), claim.to_json)
      mirror_claim(current_user_email)
      true
    rescue *WRITE_FAILURES => e
      Rails.logger.error "AIM could not claim #{@invoice_id.inspect} in #{@queue}: #{e.class}: #{e.message}"
      false
    end

    # Addresses are compared without case because that is how the pfa work
    # provider compares them, and a queue that says "Review Invoice" while the
    # review page says "read only" is worse than either answer on its own.
    def own_claim?(owner)
      owner.present? && owner.to_s.casecmp?(current_user_email.to_s)
    end

    def claimed_by_other?(folder_path)
      owner, = claim_details_for(folder_path)
      owner.present? && !own_claim?(owner)
    end

    # Names whoever is holding the claim, for a banner or an alert. Falls back
    # to the mailbox so a queue never has to show a full address.
    def claimant_label_for(folder_path)
      owner, name = claim_details_for(folder_path)
      name.presence || owner.to_s.split('@').first.presence || 'Another reviewer'
    end

    def unclaim_invoice(folder_path)
      FileUtils.rm_f(File.join(folder_path, '.claim.json'))
      mirror_release
    end

    def reject_invoice
      unclaim_invoice(@folder_path)

      submitter = metadata_param_value('Submitter', 'Submitted by') || 'Unknown'
      budget_unit = metadata_param_value('BU', 'BudgetUnit', 'Budget Unit Number') || 'Unknown'
      reject_dir = File.join(Aim::InvoiceDirectoryService.instance.rejected_dir.to_s, "#{submitter}_#{budget_unit}")

      FileUtils.mkdir_p(reject_dir)
      FileUtils.mv(@folder_path, File.join(reject_dir, @invoice_id))
      record_move('rejected')

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
        write_reprocess_sidecar(metadata_path, current_metadata)
      end

      move_invoice_to(Aim::InvoiceDirectoryService.instance.ready_to_learn_dir, 'Vendor Alias sent to Learner Queue.',
                      state: 'ready_to_learn')
    rescue ArgumentError => e
      redirect_to aim_invoice_path(@invoice_id, queue: @queue), alert: e.message
    rescue Aim::VendorAliasService::AliasStoreError => e
      Rails.logger.error "Failed to save AIM vendor alias: #{e.message}"
      redirect_to aim_invoice_path(@invoice_id, queue: @queue), alert: 'Vendor alias could not be saved to the alias file.'
    end

    # The `readonly` attribute on an input is only a hint to the browser, so
    # this is what actually keeps pipeline-owned values from being rewritten by
    # a crafted post. Keys dropped here keep whatever the pipeline last wrote —
    # write_metadata merges, so omitting a key leaves it untouched.
    def writable_metadata_params
      return {} if params[:metadata].blank?

      protected_fields = helpers.aim_readonly_fields(@queue) + helpers.aim_hidden_fields(@queue)
      protected_fields += Aim::InvoicesHelper::VENDOR_REVIEW_PROTECTED_FIELDS if @queue == 'vendor_review'

      params[:metadata].to_unsafe_h.except(*protected_fields)
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

    # Vendor Review keeps its whole folder and moves it, so its sidecar is the
    # metadata file already in there; Retry copies out a lone PDF, so its
    # sidecar is a new file named after that copy. Same contents either way.
    def write_reprocess_sidecar(sidecar_path, metadata)
      File.write(sidecar_path, JSON.pretty_generate(Aim::ReprocessSidecar.for(metadata)))
    end

    def move_invoice_to(destination_dir, notice, state:)
      return redirect_to aim_invoice_path(@invoice_id, queue: @queue), alert: 'Destination queue is not configured.' if destination_dir.blank?

      unclaim_invoice(@folder_path)
      FileUtils.mkdir_p(destination_dir)
      FileUtils.mv(@folder_path, File.join(destination_dir, @invoice_id))
      record_move(state)

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
