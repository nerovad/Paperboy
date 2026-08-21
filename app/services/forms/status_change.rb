# frozen_string_literal: true

# app/services/forms/status_change.rb

module Forms
  # Policy for changing a submission's status from its detail page.
  #
  # A form configured with the inbox "Status Dropdown" button loses that control
  # the moment it reaches an end state: the inbox is a work queue and drops
  # finished work (see Forms::InboxQuery), so from then on the submission only
  # lives in Submissions. This is the same dropdown, reachable from there — used
  # by the "Change Status" button on a submission's page and by
  # SubmissionsController#update_status, so the button can never offer something
  # the endpoint would refuse.
  module StatusChange
    # Legacy hardcoded forms — no Forms::Template, so no inbox_buttons array —
    # whose inbox row carries a status dropdown. Currently only the Critical
    # Information Report; see the hardcoded branch in inbox/queue.html.erb.
    HARDCODED_STATUS_DROPDOWN_FORMS = %w[CriticalInformationReporting].freeze

    # Routing-step statuses. Left out of the dropdown because `step_N_pending`
    # belongs to the approval engine, which picks the approver as it moves a
    # form along — setting one by hand would strand the submission at a step
    # with nobody assigned to it.
    ROUTING_STEP_STATUS = /\Astep_\d+_pending\z/

    module_function

    # True when this form type offers a status dropdown at all.
    def available_for?(record)
      klass = record.class
      return false unless klass.include?(TrackableStatus)
      return true if HARDCODED_STATUS_DROPDOWN_FORMS.include?(klass.name)

      template = Forms::Template.find_by(class_name: klass.name)
      template.present? && template.inbox_button?('status_dropdown')
    end

    # Who may make the change: system admins, and whoever the submission is
    # assigned to — the CIR's incident manager, or the approver a dynamic form
    # was stamped with when it was actioned (see
    # TrackableStatus#stamp_actor_on_terminal_status). Deliberately not the
    # submitter: nobody gets to approve or reopen their own form.
    def permitted?(record, employee_id:, group_names: [])
      return true if group_names.map(&:to_s).include?('system_admins')

      viewer = employee_id.to_s
      return false if viewer.blank?

      assignee_ids(record).include?(viewer)
    end

    # [label, key] pairs for the dropdown, labelled from the central
    # form_template_statuses catalog where the form has one.
    def options(record)
      klass = record.class
      return [] unless klass.respond_to?(:statuses)

      klass.statuses.keys
           .reject { |key| key.to_s.match?(ROUTING_STEP_STATUS) }
           .map { |key| [klass.status_label_for(key), key.to_s] }
    end

    # Employee ids the submission currently sits with, across the assignment
    # columns the different form families use.
    def assignee_ids(record)
      %i[current_assignee_id approver_id assigned_manager_id].filter_map do |attribute|
        record.public_send(attribute).presence&.to_s if record.respond_to?(attribute)
      end
    end
  end
end
