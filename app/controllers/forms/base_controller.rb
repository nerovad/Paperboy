# frozen_string_literal: true

module Forms
  # Shared behaviour for every form's own controller.
  class BaseController < ApplicationController
    # Opening one submission — its page, PDF, attachments, or any action on it
    # — is limited to the people the app already shows it to (see
    # Forms::SubmissionAccess). Every form's member routes carry the record id
    # as :id, so one guard covers them all; collection actions (index, new,
    # create) have none and are untouched. Declared ahead of the edit guard,
    # and after ApplicationController#require_sign_in, so a signed-out visitor
    # is still sent to sign in and back.
    before_action :authorize_submission_view!, if: -> { params[:id].present? }

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

    # A routing step can be configured so that its approver finishes it by
    # saving the form instead of pressing Approve (see
    # TrackableStatus#complete_step_on_edit!). Hooked here, like the guards
    # above, so every form's update honours the setting without each generated
    # controller having to call it. Runs after the action so anything the
    # action does with the saved record (Safety Reporting spawning its OSHA
    # report) has already happened.
    after_action :complete_routing_step_on_edit, if: -> { action_name == 'update' }

    private

    # Every update here answers a successful save with a redirect and a failed
    # one by re-rendering the form, so a redirect is the sign the edit landed.
    def complete_routing_step_on_edit
      return unless response.redirect?

      record = submission_model&.find_by(id: params[:id])
      return unless record.respond_to?(:complete_step_on_edit!)

      record.complete_step_on_edit!(session.dig(:user, 'employee_id'))
    rescue StandardError => e
      Rails.logger.error("complete-on-edit failed for #{controller_name} ##{params[:id]}: #{e.message}")
      flash[:alert] = 'Your changes were saved, but the submission could not be moved to its next step.'
    end

    # The model this controller edits. Every controller under Forms:: is named
    # after its model (telework_log_forms -> TeleworkLogForm), so the guard can
    # find the record without each controller wiring itself up.
    def submission_model
      controller_name.classify.safe_constantize
    end

    def authorize_submission_view!
      model = submission_model
      return unless model.respond_to?(:find_by)

      record = model.find_by(id: params[:id])
      return if record.nil? || helpers.can_view_submission?(record)

      redirect_to submissions_path, alert: "You don't have access to that submission."
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
