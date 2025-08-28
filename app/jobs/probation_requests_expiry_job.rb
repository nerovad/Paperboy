# app/jobs/probation_requests_expiry_job.rb
class ProbationRequestsExpiryJob < ApplicationJob
  queue_as :default

  def perform
    ProbationTransferRequest
      .where("expires_at <= ?", Time.current)
      .where(canceled_at: nil)
      .find_each(&:expire_if_due!)
  end
end
