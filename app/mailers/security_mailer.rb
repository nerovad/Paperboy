class SecurityMailer < ApplicationMailer
  default from: "fleet.forms@ventura.org"

  def notify(submission)
    @submission = submission
    attachments["ParkingLotSubmission_#{submission.id}.pdf"] = {
      mime_type: "application/pdf",
      content: ParkingLotPdfGenerator.generate(submission)
    }
    mail(
      to: "matthew.davoren@ventura.org",
      subject: "New Parking Permit Submission Approved"
    )
  end

  # NEW: send to the employee when denied
  def denied(submission)
    @submission = submission
    @reason     = submission.denial_reason
    attachments["ParkingLotSubmission_#{submission.id}.pdf"] = {
      mime_type: "application/pdf",
      content: ParkingLotPdfGenerator.generate(submission)
    }
    mail(
      to: submission.email,                    # the submitter
      subject: "Your Parking Permit Request ##{submission.id} was denied"
    )
  end

  def notify_delegated_approver(submission)
    @submission = submission
    @approver_email = submission.delegated_approver_email
    
    mail(
      to: @approver_email,
      subject: "Parking Permit Approval Required - #{submission.name}"
    )
  end
end
