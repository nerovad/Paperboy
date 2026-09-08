# frozen_string_literal: true

module Forms
  # Shared behaviour for every form's own controller.
  class BaseController < ApplicationController
    # Editing a submission used to be unguarded: any signed-in user who could
    # reach the URL could rewrite anybody's form. One guard here covers every
    # form rather than sixteen copies of the same check, and it runs on the
    # endpoint rather than only hiding a button — a hand-typed /edit URL is
    # refused just the same.
    #
    # Guarded with :if rather than :only because several forms (parking lot,
    # carpool, gym locker, creative job request, social media) are submit-only
    # and define no edit/update at all; Rails raises on an :only naming an
    # action the controller doesn't have.
    before_action :authorize_submission_edit!, if: -> { action_name.in?(%w[edit update]) }

    private

    # The model this controller edits. Every controller under Forms:: is named
    # after its model (telework_log_forms -> TeleworkLogForm), so the guard can
    # find the record without each controller wiring itself up.
    def submission_model
      controller_name.classify.safe_constantize
    end

    def authorize_submission_edit!
      model = submission_model
      return unless model.respond_to?(:find_by)

      record = model.find_by(id: params[:id])
      # No record: let the action's own lookup raise the usual 404 instead of
      # answering "forbidden" for something that doesn't exist.
      return if record.nil?
      return if helpers.can_edit_submission?(record)

      redirect_to submission_redirect_for(record),
                  alert: "You don't have permission to edit this submission."
    end

    # Back to the submission itself when it has a page of its own, and to the
    # Submissions list when it hasn't.
    def submission_redirect_for(record)
      polymorphic_path(record)
    rescue StandardError
      submissions_path
    end
  end
end
