# Renders a "Workflow History" section (status transitions + timestamps + who
# acted) into a Prawn document. Shared by every PDF generator so the approval/
# denial lifecycle appears on the printable/emailable record. No-op for records
# that don't track status, and never raises (a PDF must still render).
class PdfWorkflowHistory
  def self.render(pdf, submission)
    return unless submission.respond_to?(:status_timeline)

    changes = submission.status_timeline.to_a
    return if changes.empty?

    pdf.move_down 15
    pdf.text "Workflow History", size: 14, style: :bold
    pdf.move_down 5

    changes.each do |change|
      when_str = change.created_at&.strftime('%b %d, %Y %I:%M %p')
      transition = if change.from_status.present?
                     "#{change.from_status} -> #{change.to_status}"
                   else
                     change.to_status.to_s
                   end
      actor = change.changed_by_name.presence || "System"
      pdf.text "#{when_str} - #{transition} (by #{actor})", size: 10
    end
  rescue StandardError => e
    Rails.logger.warn("PdfWorkflowHistory render skipped: #{e.message}")
  end
end
