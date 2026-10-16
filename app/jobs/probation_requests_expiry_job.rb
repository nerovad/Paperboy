# frozen_string_literal: true

class ProbationRequestsExpiryJob < ApplicationJob
  queue_as :default

  def perform
    ProbationTransferRequest
      .where('expires_at <= ?', Time.current)
      .where(canceled_at: nil)
      .find_each(&:expire_if_due!)
  end
end
