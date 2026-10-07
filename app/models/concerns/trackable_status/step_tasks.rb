# frozen_string_literal: true

module TrackableStatus
  # The half of the approval engine that handles a routing step with several
  # routes (Forms::TemplateRoutingStep 'multiple').
  #
  # The submission's status still names the step it stands at, exactly as it
  # does for a single-route step. What is new is a checklist beside it: one
  # Forms::SubmissionStepTask per route, opened when the submission arrives and
  # closed by whoever that route named. Approve and Deny close the actor's own
  # task; the step's completion and deny rules then say whether the form waits,
  # moves on, or is denied.
  #
  # Nothing here runs for a single-route step, which has no tasks.
  module StepTasks
    extend ActiveSupport::Concern

    included do
      has_many :step_tasks, as: :submission, class_name: 'Forms::SubmissionStepTask', dependent: :destroy

      # Every form's deny action sets a denied status straight on the record,
      # so the deny rule is applied where that write lands rather than in each
      # generated controller.
      before_update :settle_step_task_on_denial, if: :will_save_change_to_status?
      after_update :cancel_step_tasks_left_behind, if: :saved_change_to_status?
    end

    # The checklist for the step this submission stands at, in route order.
    # Empty for a single-route step and for a form that isn't mid-step.
    def current_step_tasks
      number = current_routing_step_number
      return [] unless number

      step_tasks.where(step_number: number).ordered.to_a
    end

    private

    # Opens one task per route as the submission arrives on a multi-route step.
    # Tasks left from an earlier visit to the same step are dropped first, so a
    # new round is never settled by an old answer; the status history keeps them.
    def open_step_tasks(step)
      step_tasks.where(step_number: step.step_number).destroy_all

      step.routes.each_with_index do |route, position|
        step_tasks.create!(
          route.slice(*Forms::TemplateStepRoute::COLUMNS - ['label']).merge(
            step_number: step.step_number, position: position,
            label: route.task_label, assignee_id: route.assignee_id_for(self)
          )
        )
      end
    end

    # Closes every open task at `step` that is in the actor's hands and says
    # what that means for the form:
    #
    #   :noop    -- the actor holds no open task here; nothing was changed
    #   :waiting -- recorded, and other routes still owe an answer
    #   :advance -- the step is finished and the form moves on
    #   :denied  -- the step is finished and the form is denied
    #
    # The submission row is locked for the duration, so two approvers answering
    # at once are settled one after the other and only one of them moves the form.
    def settle_step_task(step, state, actor_id = nil)
      actor = (actor_id.presence || Current.user&.dig('employee_id')).to_s

      self.class.transaction do
        self.class.lock.where(id: id).pick(:id)
        tasks = step_tasks.where(step_number: step.step_number).ordered.to_a
        mine = tasks.select { |task| task.open_to?(actor, self) }

        if mine.empty?
          :noop
        else
          mine.each { |task| close_step_task(task, state, actor) }
          step_task_outcome(step, tasks)
        end
      end
    end

    def close_step_task(task, state, actor)
      notes = Current.deny_reason.presence if state == Forms::SubmissionStepTask::DENIED
      task.close!(state, actor_id: actor, actor_name: current_user_display_name, notes: notes)
      status_changes.create!(
        from_status: task.label,
        to_status: "#{task.label}: #{task.state_label}",
        changed_by_id: actor,
        changed_by_name: current_user_display_name,
        notes: notes
      )
    end

    # What the checklist adds up to under the step's two rules.
    def step_task_outcome(step, tasks)
      pending = tasks.any?(&:pending?)
      approved = tasks.any?(&:approved?)
      denied = tasks.any?(&:denied?)

      return :denied if denied && step.deny_rule == 'form'

      if step.completion_rule == 'any'
        return :advance if approved

        pending ? :waiting : :denied
      else
        return :waiting if pending

        denied ? :denied : :advance
      end
    end

    # Denies the form once its checklist has decided on a denial, bypassing the
    # deny rule below: the tasks have already been settled.
    def finalize_step_denial!
      key = self.class.statuses_for_category(:denied).first || :denied
      @step_tasks_settled = true
      update!(status: key.to_s)
    ensure
      @step_tasks_settled = false
    end

    # A denied status is about to be written while the submission stands at a
    # multi-route step. Record the denial on the actor's task, and when the
    # step's rules say the form is not denied yet, put the status back so it
    # stays where it is until the remaining routes have answered.
    #
    # Someone holding no open task here cannot answer for a route. Under the
    # 'task' rule their deny changes nothing; under the 'form' rule any one
    # deny ends the form, so theirs is let through as it always was.
    def settle_step_task_on_denial
      return if @step_tasks_settled
      return unless self.class.status_category_for(status) == :denied

      step = routing_step_being_left
      return unless step&.multiple?

      outcome = settle_step_task(step, Forms::SubmissionStepTask::DENIED)
      return if outcome == :denied
      return if outcome == :noop && step.deny_rule == 'form'

      restore_attributes(['status'])
    end

    def routing_step_being_left
      number = self.class.status_key_for(status_was).to_s[/\Astep_(\d+)_pending\z/, 1]
      return nil unless number

      approval_template&.routing_steps&.find_by(step_number: number.to_i)
    end

    # Once the submission has left a step, by any road, whatever is still open
    # on that step's checklist is owed by nobody.
    def cancel_step_tasks_left_behind
      stale = step_tasks.pending
      here = current_routing_step_number
      stale = stale.where.not(step_number: here) if here

      stale.update_all(state: Forms::SubmissionStepTask::CANCELLED, updated_at: Time.current)
    end
  end
end
