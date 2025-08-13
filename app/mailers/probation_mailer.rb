class ProbationMailer < ApplicationMailer
  default from: "fleet.forms@ventura.org"

  def notify(request)
    @request = request

    attachments["ProbationTransferRequest_#{request.id}.pdf"] = {
      mime_type: 'application/pdf',
      content: ProbationTransferPdfGenerator.generate(request)
    }

    mail(
      to: "matthew.davoren@ventura.org",
      subject: "New Probation Transfer Request Submitted"
    )
  end
end
