# frozen_string_literal: true

module Aim
  # What the stamp designer (#221) lays a stamp on: one of the group's own
  # invoices (any invoice, for the default), or a PDF the person uploads.
  # Included by Aim::StampLayoutsController, beside Aim::StoredPdf.
  module StampSamples
    extend ActiveSupport::Concern

    SAMPLE_LIMIT = 25
    UPLOAD_LIMIT = 25.megabytes

    private

    # The group's invoices (any, for the default), newest first, that have a
    # PDF: what the designer offers to lay the stamp on.
    def sample_scope
      scope = @group ? helpers.aim_agency_groups.invoices([@group]) : Aim::Invoice.all
      scope.where.not(state: %w[deleted split]).where(pdf_purged_at: nil)
    end

    def sample_invoices = sample_scope.order(id: :desc).limit(SAMPLE_LIMIT).to_a

    def sample_invoice(id) = id.present? ? sample_scope.find_by(id: id) : sample_scope.order(id: :desc).first

    # [path, values] for a check: a group invoice, or an uploaded PDF, filled
    # as the designer's "Fill with" says (fill_values); nil when there is
    # neither, or the upload is not a PDF or too big.
    def preview_source
      if (upload = params[:file]).respond_to?(:path)
        return if upload.size > UPLOAD_LIMIT || File.binread(upload.path, 5) != '%PDF-'

        return [upload.path, fill_values(nil)]
      end
      invoice = sample_invoice(params[:invoice_id])
      path = invoice && store_file(invoice, 'pdf')
      [path, fill_values(invoice)] if path
    end

    # "worst": every field at its longest; "samples"; otherwise the invoice's
    # own values with samples where they are empty (samples for an upload).
    def fill_values(invoice)
      case params[:fill]
      when 'worst' then Aim::StampFields.worst_case
      when 'samples' then Aim::StampFields.samples(agency: @group&.agency_id)
      else invoice ? Aim::StampFields.with_samples(invoice) : Aim::StampFields.samples(agency: @group&.agency_id)
      end
    end
  end
end
