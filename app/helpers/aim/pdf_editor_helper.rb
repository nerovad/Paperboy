# frozen_string_literal: true

module Aim
  # What the Edit PDF editor is handed (#182): the current version's base PDF,
  # its inserted PDFs and its plan, so it opens where the last person left it.
  module PdfEditorHelper
    def aim_pdf_editor_data(invoice)
      version = Aim::PdfVersions.current(invoice)
      inserts = (1..(version&.insert_files&.size || 0)).map { |n| aim_pdf_source_invoice_path(invoice.batch_id, insert: n) }
      { controller: 'aim-pdf-editor', aim_pdf_editor_pdf_url_value: aim_pdf_source_invoice_path(invoice.batch_id),
        aim_pdf_editor_insert_urls_value: inserts.to_json, aim_pdf_editor_plan_value: version&.plan || 'null',
        aim_pdf_editor_splitting_value: invoice.state == 'needs_split',
        aim_pdf_editor_split_starts_value: Aim::SplitPlan.starts_from_manifest(invoice.manifest_data).to_json }
    end

    # "v4 · 10/19/26 2:10 PM · joshua.gannon · PDF edited: text added to page 2"
    def aim_pdf_version_line(version)
      who = version.created_by.to_s.split('@').first
      ["v#{version.number}", version.created_at.in_time_zone.strftime('%m/%d/%y %-I:%M %p'), who, version.note].compact_blank.join(' · ')
    end
  end
end
