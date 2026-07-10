# frozen_string_literal: true

# Renders a submission's human-readable reference number (e.g. "LOA-1042") into
# a Prawn document. Shared by every PDF generator so the printable/emailable
# record carries the same id users search on in the inbox. No-op for records
# without a reference, and never raises (a PDF must still render).
class PdfReference
  def self.render(pdf, submission)
    reference = FormReference.reference_for(submission)
    return if reference.blank?

    pdf.text "Reference: #{reference}", size: 11, style: :bold, align: :right
    pdf.move_down 8
  rescue StandardError => e
    Rails.logger.warn("PdfReference render skipped: #{e.message}")
  end
end
