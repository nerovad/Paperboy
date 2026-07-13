# frozen_string_literal: true

class SecurityMailer < ApplicationMailer
  default from: 'gsa-forms@ventura.org'

  # Sends to the employee when their parking request is denied.
  def denied(submission)
    @submission = submission
    @reason     = submission.denial_reason
    attachments["ParkingLotSubmission_#{submission.id}.pdf"] = {
      mime_type: 'application/pdf',
      content: ParkingLotPdfGenerator.generate(submission)
    }
    mail(
      to: submission.email, # the submitter
      subject: "Your Parking Permit Request ##{submission.id} was denied"
    )
  end
end
