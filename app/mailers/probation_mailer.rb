class ProbationMailer < ApplicationMailer
  default from: "fleet.forms@ventura.org"

  def notify(submission)
    @submission = submission

    attachments["ProbationTransferRequest_#{submission.id}.pdf"] =
      ProbationTransferPdfGenerator.generate(submission)

    mail(
      to: "matthew.davoren@ventura.org",
      subject: "Probation Transfer Request Approved"
    )
  end

  def denied(request)
    @request = request
    @reason  = request.denial_reason

    mail(
      to: @request.email, # employee who submitted
      subject: "Probation Transfer Request Denied"
    )
  end
end
