# frozen_string_literal: true

class Current < ActiveSupport::CurrentAttributes
  attribute :user # Stores session[:user] hash

  # The reason typed into the deny modal, for the engine to file against the
  # task it closes (TrackableStatus::StepTasks); set by Forms::BaseController.
  attribute :deny_reason
end
