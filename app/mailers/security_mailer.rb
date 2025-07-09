class SecurityMailer < ApplicationMailer
  default from: "fleet.forms@ventura.org"

  def notify(submission)
    @submission = submission

    attachments["ParkingLotSubmission_#{submission.id}.pdf"] = {
      mime_type: 'application/pdf',
      content: ParkingLotPdfGenerator.generate(submission)
    }

    mail(
      to: "matthew.davoren@ventura.org",
      subject: "New Parking Lot Submission Approved"
    )
  end
end
