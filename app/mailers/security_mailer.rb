class SecurityMailer < ApplicationMailer
  default from: "fleet.forms@ventura.org"

  def notify(submission)
    @submission = submission
    mail(
      to: "matthew.davoren@ventura.org",
      subject: "New Parking Lot Submission Approved"
    )
  end
end
