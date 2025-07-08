class NotifySecurityJob < ApplicationJob
  queue_as :default

  def perform(submission_id)
    submission = ParkingLotSubmission.find(submission_id)

    # Example mailer (create one if you haven’t)
    SecurityMailer.notify(submission).deliver_now
  end
end

