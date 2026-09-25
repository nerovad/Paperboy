# frozen_string_literal: true

module Forms
  # Who may open one submission: its detail page, PDF, attachments and status
  # timeline. The answer is whatever already puts the submission in front of
  # the viewer somewhere in the app — nothing new to configure. Anyone the
  # Submissions list, the Inbox or the ACL shows it to may open it; a link
  # typed or guessed by anyone else is refused.
  #
  # A viewer may open a submission when they are:
  #
  # * a system admin;
  # * its submitter;
  # * someone it sits with now — an assignee, or an approver in the pool of the
  #   routing step it waits at (Forms::SubmissionPolicy asks the same);
  # * someone who already acted on it — a status change in their name, or the
  #   approved_by / denied_by columns the older forms keep;
  # * a "Send a Copy To" recipient (Forms::SubmissionCopy);
  # * above the submitter or a current assignee in the supervisor chain, as the
  #   Submissions and Inbox employee filters allow;
  # * the holder of an ACL visibility grant whose form and org window cover it
  #   (Forms::VisibilityGrant, either surface);
  # * the holder of an ACL Edit or Change Status grant on the form — a right to
  #   change a submission includes seeing it.
  #
  # Subscribing to a form is deliberately not on the list: the ACL page says a
  # subscription grants no sight of a form, and this keeps it true.
  module SubmissionAccess
    ACTOR_COLUMNS = %i[approved_by denied_by].freeze
    ASSIGNEE_COLUMNS = %i[supervisor_id].freeze

    module_function

    def viewable?(record, employee_id:, group_names: [], group_ids: [], permission_keys: [])
      return true if Array(group_names).map(&:to_s).include?('system_admins')

      viewer = employee_id.to_s
      return false if viewer.blank?

      involved?(record, viewer) ||
        supervises?(record, viewer) ||
        granted?(record, viewer, group_ids) ||
        Forms::SubmissionPolicy::ACTIONS.any? do |action|
          Forms::SubmissionPolicy.granted?(record, action, permission_keys)
        end
    end

    # The viewer's own relationship to the submission, cheapest checks first.
    def involved?(record, viewer)
      Forms::SubmissionPolicy.submitter?(record, viewer) ||
        people_on(record).include?(viewer) ||
        Forms::SubmissionPolicy.pool_approver?(record, viewer) ||
        acted_on?(record, viewer) ||
        copied_to?(record, viewer)
    end

    # Submitter and current assignees — everyone a supervisor might be above.
    def people_on(record)
      assignees = Forms::SubmissionPolicy.assignee_ids(record)
      assignees += ASSIGNEE_COLUMNS.filter_map { |column| record.try(column).presence&.to_s }
      assignees
    end

    def acted_on?(record, viewer)
      return true if ACTOR_COLUMNS.any? { |column| record.try(column).to_s == viewer }
      return false unless record.respond_to?(:status_changes)

      record.status_changes.exists?(changed_by_id: viewer)
    end

    def copied_to?(record, viewer)
      Forms::SubmissionCopy.exists?(submission_type: record.class.name, submission_id: record.id,
                                    recipient_employee_id: viewer.to_i)
    end

    # Above the submitter or a current assignee in the reporting chain. Walks
    # the chain upward from those few people rather than down from the viewer,
    # whose subtree can be a whole agency.
    def supervises?(record, viewer)
      people = [record.try(:employee_id).presence&.to_s, *people_on(record)].compact.uniq - [viewer]
      people.any? { |person| supervisor_chain(person).include?(viewer) }
    end

    def supervisor_chain(employee_id, limit: 25)
      chain = []
      current = employee_id.to_s
      limit.times do
        boss = Employee.where(id: current).pick(:supervisor_id).to_s
        break if boss.blank? || boss == current || chain.include?(boss)

        chain << boss
        current = boss
      end
      chain
    rescue StandardError
      []
    end

    def granted?(record, viewer, group_ids)
      grants = Forms::VisibilityGrant.for_viewer(viewer, Array(group_ids)).to_a
      scope = Forms::VisibilityGrant.granted_scope(grants, record.class)
      !scope.nil? && scope.exists?(id: record.id)
    end
  end
end
