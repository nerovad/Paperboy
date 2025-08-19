class ProbationMailer < ApplicationMailer
  default from: "fleet.forms@ventura.org"

  def notify(request)
    @request = request

    attachments["ProbationTransferRequest_#{request.id}.pdf"] = {
      mime_type: "application/pdf",
      content: ProbationTransferPdfGenerator.generate(request)
    }

    mail(
      to: @request.email, # or wherever it should go
      subject: "New Probation Transfer Request Submitted"
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
