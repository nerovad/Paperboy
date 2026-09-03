# frozen_string_literal: true

# app/services/forms/submission_policy.rb

module Forms
  # Who may act on a submission from its own detail page, and with which
  # statuses.
  #
  # Two actions are governed here:
  #
  # * +change_status+ — the Change Status control. A form configured with the
  #   inbox "Status Dropdown" button loses that control once it reaches an end
  #   state, because the inbox drops finished work (Forms::InboxQuery); this is
  #   the same dropdown, reachable from Submissions, where the submission still
  #   lives.
  # * +edit+ — the Edit button. Before this existed nothing checked editing at
  #   all: any signed-in user who could open a submission could rewrite it.
  #
  # Everyone starts with a baseline nobody has to configure — see #permitted? —
  # and ACL grants widen it from there. Grants are ordinary group/org permission
  # rows of type 'submission_action', keyed "<action>:<FormClass>", so they flow
  # through the same org → group cascade as every other permission and can be
  # issued to a group (ACL › group › permissions) or to everyone in an agency,
  # division, department or unit (ACL › Organization Permissions).
  module SubmissionPolicy
    PERMISSION_TYPE = 'submission_action'

    # action key => how the ACL screens name it.
    ACTION_LABELS = {
      'change_status' => 'Change Status',
      'edit' => 'Edit'
    }.freeze
    ACTIONS = ACTION_LABELS.keys.freeze

    # Sentinel for a grant covering every form, matching the one visibility
    # grants use so the two screens read the same way.
    ALL_FORMS = Forms::VisibilityGrant::ALL_FORMS

    # Legacy hardcoded forms — no Forms::Template, so no inbox_buttons array —
    # whose inbox row carries a status dropdown. Currently only the Critical
    # Information Report; see the hardcoded branch in inbox/queue.html.erb.
    HARDCODED_STATUS_DROPDOWN_FORMS = %w[CriticalInformationReporting].freeze

    # Routing-step statuses. Left out of the dropdown because `step_N_pending`
    # belongs to the approval engine, which picks the approver as it moves a
    # form along — setting one by hand would strand the submission at a step
    # with nobody assigned to it. The capture also names the step a submission
    # is currently sitting at — see #current_routing_step.
    ROUTING_STEP_STATUS = /\Astep_(\d+)_pending\z/

    module_function

    # The ACL permission key granting +action+ on +form_type+.
    def permission_key(action, form_type)
      "#{action}:#{form_type}"
    end

    # True when this form type offers a status dropdown at all.
    def status_dropdown?(record)
      klass = record.class
      return false unless klass.include?(TrackableStatus)
      return true if HARDCODED_STATUS_DROPDOWN_FORMS.include?(klass.name)

      template = Forms::Template.find_by(class_name: klass.name)
      template.present? && template.inbox_button?('status_dropdown')
    end

    # [label, key] pairs for the status dropdown, labelled from the central
    # form_template_statuses catalog where the form has one.
    def status_options(record)
      klass = record.class
      return [] unless klass.respond_to?(:statuses)

      klass.statuses.keys
           .reject { |key| key.to_s.match?(ROUTING_STEP_STATUS) }
           .map { |key| [klass.status_label_for(key), key.to_s] }
    end

    # May this viewer take +action+ on this submission?
    #
    # The baseline, true with no ACL grant anywhere:
    #
    # * system admins, always;
    # * whoever the submission is assigned to — the CIR's incident manager, or
    #   the approver a dynamic form was stamped with when it was actioned (see
    #   TrackableStatus#stamp_actor_on_terminal_status);
    # * anyone eligible to approve it at the routing step it is sitting at.
    #   A pool step (group / authorization) leaves approver_id nil so the whole
    #   queue can act on it, so the assignment columns can't see those
    #   approvers even though the form is squarely in their hands;
    # * for +edit+ only, the person who filed it. Deliberately not for
    #   +change_status+: nobody approves or reopens their own form.
    #
    # +permission_keys+ is the viewer's 'submission_action' key set, which
    # widens the baseline to anyone an ACL grant names.
    #
    # +routing_step+ lets a caller that already holds the submission's current
    # step hand it over rather than have it looked up again — the inbox queue
    # does, once per row.
    def permitted?(record, action:, employee_id:, group_names: [], permission_keys: [], routing_step: nil)
      action = action.to_s
      return false unless ACTIONS.include?(action)
      return true if group_names.map(&:to_s).include?('system_admins')

      viewer = employee_id.to_s
      return false if viewer.blank?
      return true if assignee_ids(record).include?(viewer)
      return true if pool_approver?(record, viewer, routing_step)
      return true if action == 'edit' && submitter?(record, viewer)

      granted?(record, action, permission_keys)
    end

    # Employee ids the submission currently sits with, across the assignment
    # columns the different form families use.
    def assignee_ids(record)
      %i[current_assignee_id approver_id assigned_manager_id].filter_map do |attribute|
        record.public_send(attribute).presence&.to_s if record.respond_to?(attribute)
      end
    end

    # True when the viewer is one of the people the current routing step routes
    # to. Asks the step the same question the inbox asks when it decides whose
    # queue the row belongs in, so a viewer who sees Approve also sees Edit.
    def pool_approver?(record, employee_id, step = nil)
      step ||= current_routing_step(record)
      return false unless step

      step.eligible_approver_ids(record).map(&:to_s).include?(employee_id.to_s)
    end

    # The routing step named by a `step_N_pending` status, or nil for a form
    # that isn't routed or has moved past its steps.
    def current_routing_step(record)
      return nil unless record.respond_to?(:status)

      match = record.status.to_s.match(ROUTING_STEP_STATUS)
      return nil unless match

      template = Forms::Template.find_by(class_name: record.class.name)
      template&.routing_steps&.find_by(step_number: match[1].to_i)
    end

    def submitter?(record, employee_id)
      record.respond_to?(:employee_id) && record.employee_id.to_s.presence == employee_id.to_s.presence
    end

    # Does the viewer hold an ACL grant for this action, on this form or on
    # every form?
    def granted?(record, action, permission_keys)
      keys = Array(permission_keys).map(&:to_s)
      return false if keys.empty?

      keys.include?(permission_key(action, record.class.name)) ||
        keys.include?(permission_key(action, ALL_FORMS))
    end
  end
end
