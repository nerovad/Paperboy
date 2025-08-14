class NotifyProbationJob < ApplicationJob
  queue_as :default

  def perform(request_id)
    request = ProbationTransferRequest.find(request_id)
    ProbationMailer.notify(request).deliver_now
  end
end
