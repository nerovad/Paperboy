# frozen_string_literal: true

module Aim
  # The Batch Split review page's two answers. Plan step 5.7c.
  #
  # Approve Split takes a person's corrected split, checks it makes sense
  # (Aim::SplitPlan), writes it into the manifest the splitter reads -- keeping
  # the BU, submitter and owner the AI worker put there -- and sends the batch
  # to the splitter. It replaces dragging the folder onto the
  # MOVE_FOLDERS_HERE_TO_SPLIT shortcut after editing the manifest by hand.
  #
  # Process as One Invoice is for a batch the AI was wrong about. It goes back
  # through extraction with the split check bypassed, keeping its own batch id
  # so its history carries on rather than a new invoice starting.
  module InvoiceSplitting
    extend ActiveSupport::Concern

    private

    def approve_split
      plan = split_plan_from_params
      return show_split_errors(plan) unless plan.valid?

      manifest_path = split_manifest_path
      manifest = plan.manifest(read_split_manifest(manifest_path))
      File.write(manifest_path, JSON.pretty_generate(manifest))

      move_invoice_to(Aim::InvoiceDirectoryService.instance.ready_to_split_dir,
                      "Split approved into #{manifest['invoices'].size} invoices. " \
                      'Each appears in the queues as it is processed.',
                      state: 'ready_to_split')
    end

    def process_as_one_invoice
      manifest = read_split_manifest(split_manifest_path)
      row = Aim::Invoice.find_by(batch_id: @invoice_id)
      sidecar = {
        'bu' => manifest['bu'].presence || row&.budget_unit,
        'submitter' => manifest['submitter'].presence || row&.submitter,
        'owner' => manifest['owner'].presence || row&.assigned_to,
        'bypass_split' => true,
        'processing_id' => @invoice_id
      }.compact
      File.write(File.join(@folder_path, "#{@invoice_id}.json"), JSON.pretty_generate(sidecar))

      move_invoice_to(Aim::InvoiceDirectoryService.instance.reprocess_dir,
                      'Sent back through extraction as one invoice.', state: 'reprocess')
    end

    # The rows the page shows: what the person typed if a split was refused,
    # otherwise what the manifest proposes.
    def load_split_context
      @split_page_count = batch_page_count
      @split_rows = @split_plan&.rows || Aim::SplitPlan.rows_from_manifest(@metadata)
    end

    # Rows arrive as split[0][pages_text] and so on, one per invoice.
    def split_plan_from_params
      rows = params.fetch(:split, {}).to_unsafe_h.sort_by { |index, _| index.to_i }.map do |_, row|
        row.slice('vendor_name', 'invoice_number', 'pages_text')
      end
      Aim::SplitPlan.new(rows, page_count: batch_page_count)
    end

    # The page comes back with what the person typed and why it was refused,
    # rather than redirecting and losing their work.
    def show_split_errors(plan)
      @split_plan = plan
      prepare_review
      flash.now[:alert] = 'The split was not approved. Nothing has moved.'
      render :show, status: :unprocessable_content
    end

    def batch_page_count
      pdf = pdf_files_for(@folder_path).first
      return if pdf.blank?

      require 'pdf-reader'
      PDF::Reader.new(File.join(@folder_path, pdf)).page_count
    rescue StandardError => e
      Rails.logger.warn "AIM could not count the pages of #{@invoice_id.inspect}: #{e.class}: #{e.message}"
      nil
    end

    def split_manifest_path
      Dir.glob(File.join(@folder_path, '*_MANIFEST.json')).first ||
        File.join(@folder_path, "#{@invoice_id}_MANIFEST.json")
    end

    def read_split_manifest(path)
      File.exist?(path) ? JSON.parse(File.read(path)) : {}
    rescue JSON::ParserError
      {}
    end
  end
end
