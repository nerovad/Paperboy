# frozen_string_literal: true

module Forms
  # One route's share of a multi-route routing step, for one submission.
  #
  # The submission's status says which step it stands at; its tasks say who
  # still owes an answer there. A task is opened for every route when the
  # submission arrives on the step (TrackableStatus) and closed by whoever it
  # was routed to. The step's completion and deny rules decide what a closed
  # task means for the form.
  #
  # A task copies its route's target and label rather than pointing at the
  # route: the form builder rebuilds a template's steps on every routing edit,
  # and a submission in flight keeps the checklist it was given.
  class SubmissionStepTask < ApplicationRecord
    self.table_name = 'submission_step_tasks'

    belongs_to :submission, polymorphic: true

    include Forms::RouteTarget

    PENDING = 'pending'
    APPROVED = 'approved'
    DENIED = 'denied'
    # Closed without an answer: the step was settled by another route, or the
    # submission left the step some other way.
    CANCELLED = 'cancelled'
    STATES = [PENDING, APPROVED, DENIED, CANCELLED].freeze

    STATE_LABELS = {
      PENDING => 'Pending',
      APPROVED => 'Approved',
      DENIED => 'Denied',
      CANCELLED => 'Not needed'
    }.freeze

    validates :step_number, presence: true
    validates :label, presence: true
    validates :routing_type, presence: true, inclusion: { in: TARGET_TYPES }
    validates :state, inclusion: { in: STATES }

    scope :ordered, -> { order(:step_number, :position, :id) }
    scope :pending, -> { where(state: PENDING) }

    STATES.each do |name|
      define_method(:"#{name}?") { state == name }
    end

    def state_label
      STATE_LABELS[state]
    end

    # Who may answer this task. A named assignee is the only one; a pool task
    # is open to everyone its target resolves to.
    def eligible_approver_ids(submission = self.submission)
      return [assignee_id.to_s] if assignee_id.present?

      target_approver_ids(submission).map(&:to_s)
    end

    def open_to?(employee_id, submission = self.submission)
      pending? && employee_id.present? && eligible_approver_ids(submission).include?(employee_id.to_s)
    end

    # Who the task is waiting on, for the checklist.
    def waiting_on
      return target_label if assignee_id.blank?

      Employee.find_by(employee_id: assignee_id)&.full_name || "Employee ##{assignee_id}"
    rescue StandardError
      target_label
    end

    def close!(state, actor_id: nil, actor_name: nil, notes: nil)
      update!(state: state, acted_by_id: actor_id, acted_by_name: actor_name,
              acted_at: Time.current, notes: notes)
    end
  end
end
