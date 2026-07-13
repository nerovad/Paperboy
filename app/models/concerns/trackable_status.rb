# frozen_string_literal: true

# app/models/concerns/trackable_status.rb
module TrackableStatus
  extend ActiveSupport::Concern

  # Normalized status categories for cross-form reporting
  # Each model must define STATUS_CATEGORIES mapping its statuses to these categories
  VALID_CATEGORIES = %i[pending in_review approved denied cancelled scheduled].freeze

  TERMINAL_STATUSES = %w[approved denied cancelled].freeze

  included do
    has_many :status_changes, as: :trackable, dependent: :destroy
    has_many :form_submission_copies, as: :submission, dependent: :destroy
    after_create :record_initial_status
    after_create :deliver_copy_recipients_on_submit
    after_create :deliver_email_steps_on_submit
    after_update :record_status_change, if: :saved_change_to_status?
    after_update :deliver_copy_recipients_on_approval, if: :saved_change_to_status?
    after_update :deliver_email_steps_on_status_change, if: :saved_change_to_status?
    after_update :stamp_actor_on_terminal_status, if: :saved_change_to_status?
  end

  # Class method to convert status value to label
  # Works with both enum-based and STATUS_MAP-based models
  class_methods do
    # Resolves a stored status value to its canonical string key. Handles both
    # enum-backed models (status is already the key) and legacy STATUS_MAP
    # models (status is a raw integer).
    def status_key_for(status_value)
      return nil if status_value.nil?
      return status_value.to_s unless status_value.is_a?(Integer)

      if defined_enums['status'].present?
        defined_enums['status'].key(status_value)
      elsif const_defined?(:STATUS_MAP)
        self::STATUS_MAP[status_value]
      else
        status_value.to_s
      end
    end

    # key => FormTemplateStatus for this model's template, cached per class.
    # Empty for models with no template (legacy/custom forms), which then fall
    # back to their own STATUS_LABELS / STATUS_CATEGORIES / STATUS_MAP constants.
    def central_status_definitions
      return @central_status_definitions if defined?(@central_status_definitions)

      @central_status_definitions =
        begin
          template = FormTemplate.find_by(class_name: name)
          template ? template.statuses.index_by { |s| s.key.to_s } : {}
        rescue StandardError
          {}
        end
    end

    def status_label_for(status_value)
      return nil if status_value.nil?

      key = status_key_for(status_value)

      # 1. Central source of truth: form_template_statuses
      if key && (definition = central_status_definitions[key])
        return definition.name
      end

      # 2. Legacy fallback: per-model STATUS_LABELS constant
      if const_defined?(:STATUS_LABELS)
        label = self::STATUS_LABELS[key&.to_sym]
        return label if label
      end

      key ? key.humanize : 'Unknown'
    end

    # Returns the normalized category (symbol) for a given status value.
    def status_category_for(status_value)
      return nil if status_value.nil?

      key = status_key_for(status_value)
      return nil unless key

      # 1. Central source of truth
      if (definition = central_status_definitions[key])
        return definition.category.to_sym
      end

      # 2. Legacy fallback: per-model STATUS_CATEGORIES constant
      return self::STATUS_CATEGORIES[key.to_sym] if const_defined?(:STATUS_CATEGORIES)

      nil
    end

    # True when the given status is a configured END STATE for this form —
    # one that nothing further happens after (approved / denied / cancelled,
    # or any custom status a form marks as final). The inbox uses this to drop
    # finished work; Submissions keeps everything regardless.
    #
    # Authoritative source is the per-status `is_end` flag on
    # form_template_statuses. Models without a template (or statuses missing
    # from it) fall back to the terminal categories, then to a model-declared
    # TERMINAL_STATUS_KEYS constant, and finally the global TERMINAL_STATUSES.
    def terminal_status?(status_value)
      key = status_key_for(status_value)
      return false unless key

      if (definition = central_status_definitions[key])
        return !!definition.is_end
      end

      category = status_category_for(status_value)
      return true if category && %i[approved denied cancelled].include?(category)

      # Legacy/custom forms with no template can declare their own end states
      # (e.g. CIR's "resolved") via TERMINAL_STATUS_KEYS; otherwise use the
      # global approved/denied/cancelled default.
      terminal_keys = const_defined?(:TERMINAL_STATUS_KEYS) ? self::TERMINAL_STATUS_KEYS : TERMINAL_STATUSES
      terminal_keys.map(&:to_s).include?(key.to_s)
    end

    # Returns all status keys (symbols) that belong to a given category.
    def statuses_for_category(category)
      cat = category.to_s
      if central_status_definitions.any?
        return central_status_definitions.values
                                         .select { |s| s.category.to_s == cat }
                                         .map { |s| s.key.to_sym }
      end

      return [] unless const_defined?(:STATUS_CATEGORIES)

      self::STATUS_CATEGORIES.select { |_, c| c.to_s == cat }.keys
    end

    # Returns hash of category => human-readable label
    def category_labels
      {
        pending: 'Pending',
        in_review: 'In Review',
        approved: 'Approved',
        denied: 'Denied',
        cancelled: 'Cancelled',
        scheduled: 'Scheduled'
      }
    end
  end

  def status_timeline
    status_changes.chronological
  end

  # Starts a multi-step approval flow from the first step whose condition
  # matches the submitted form. If no step matches, marks the form approved
  # immediately (treated as a no-op approval).
  # `skip_types` lets a caller bypass routing steps of certain types when
  # picking the first step (e.g. MB3 parking submitters skip the 'authorization'
  # step). Approver resolution stays centralized in approver_id_for_routing_step.
  def start_approval!(skip_types: [])
    template = approval_template
    return unless template

    steps = template.routing_steps.ordered.to_a
    return if steps.empty?

    first_step = steps.find { |s| !skip_types.include?(s.routing_type) && s.matches?(self) }
    return approved! unless first_step

    update!(
      status: "step_#{first_step.step_number}_pending",
      approver_id: approver_id_for_routing_step(first_step)
    )
    warn_if_no_eligible_approver(first_step)
  end

  # Advances a multi-step approval form to the next matching step, skipping
  # steps whose conditions evaluate false. Marks the form fully approved when
  # no further matching step remains.
  def advance_approval!
    template = approval_template
    return finalize_approval! unless template

    steps = template.routing_steps.ordered.to_a
    return finalize_approval! if steps.empty?

    current = current_routing_step_number
    return finalize_approval! if current.nil?

    next_step = steps.find { |s| s.step_number > current && s.matches?(self) }
    return finalize_approval! unless next_step

    # Before handing the form to the next approver, leave a read-only tracking
    # copy in the acting approver's inbox if the step they just cleared was a
    # multi-approver pool (group/authorization). Without this the form would
    # vanish from every pool member's queue the moment one of them acts —
    # including the person who actually actioned it.
    record_pool_step_tracking_copy(steps.find { |s| s.step_number == current })

    update!(
      status: "step_#{next_step.step_number}_pending",
      approver_id: approver_id_for_routing_step(next_step)
    )
    warn_if_no_eligible_approver(next_step)
  end

  # Human-readable label for the current status. Sourced from
  # form_template_statuses, falling back to the model's own constants.
  def status_label
    self.class.status_label_for(status)
  end

  # Returns the normalized category for the current status
  def status_category
    self.class.status_category_for(status)
  end

  # Returns the human-readable label for the current status category
  def status_category_label
    self.class.category_labels[status_category] || 'Unknown'
  end

  # Whether this submission has reached an end state — see terminal_status?.
  def terminal?
    self.class.terminal_status?(status)
  rescue StandardError
    false
  end

  private

  def finalize_approval!
    approved!
  end

  # Whenever status transitions to a terminal state (approved/denied/cancelled),
  # stamp approver_id with the acting user so the record stays in their inbox.
  # Group-routed forms would otherwise leave approver_id nil at the terminal
  # step and drop out of every inbox the moment the action is taken.
  def stamp_actor_on_terminal_status
    return unless self.class.column_names.include?('approver_id')
    return unless TERMINAL_STATUSES.include?(status.to_s)

    actor_id = Current.user&.dig('employee_id')&.to_s.presence
    return unless actor_id
    return if approver_id.to_s == actor_id

    update_columns(approver_id: actor_id)
  end

  # Pool steps (group / authorization) carry approver_id == nil so every
  # eligible approver sees the form and the first to act wins. When the form
  # then advances to a later step, drop a read-only copy row into the acting
  # approver's inbox so they keep tracking it; the other pool members simply
  # lose it from their queue. Terminal pool steps don't need this — the actor
  # is kept on via stamp_actor_on_terminal_status instead.
  def record_pool_step_tracking_copy(step)
    return unless step
    return unless %w[group authorization].include?(step.routing_type.to_s)

    actor_id = Current.user&.dig('employee_id')&.to_s.presence
    return unless actor_id

    FormSubmissionCopy.find_or_create_by!(
      submission_type: self.class.name,
      submission_id: id,
      recipient_employee_id: actor_id.to_i
    ) { |row| row.delivered_via = 'pool_action' }
  rescue ActiveRecord::RecordNotUnique
    # Concurrent action raced the unique index — the tracking copy already exists.
  rescue StandardError => e
    Rails.logger.warn("pool-step tracking copy failed for #{self.class.name} ##{id}: #{e.message}")
  end

  def approval_template
    respond_to?(:form_template) ? form_template : nil
  rescue StandardError
    nil
  end

  def current_routing_step_number
    status&.to_s&.match(/\Astep_(\d+)_pending\z/)&.captures&.first&.to_i
  end

  def approver_id_for_routing_step(step)
    case step.routing_type
    when 'supervisor'
      submitter_employee&.supervisor_id&.to_s
    when 'department_head'
      emp = submitter_employee
      return nil unless emp

      unit = Unit.find_by(unit_id: emp.unit)
      department = unit ? Department.find_by(department_id: unit.department_id) : nil
      department&.department_head_id&.to_s
    when 'employee'
      step.employee_id.to_s
    when 'group', 'authorization'
      # Multi-approver queue: approver_id stays nil so every eligible approver
      # (group members / authorized approvers for the budget unit) sees it in
      # their inbox; the first to act claims it.
      nil
    end
  end

  def submitter_employee
    return nil unless respond_to?(:employee_id) && employee_id.present?

    # Employee or Contractor — both expose supervisor_id/unit for routing.
    Submitter.resolve(employee_id)
  end

  def record_initial_status
    status_changes.create!(
      from_status: nil,
      to_status: status_label,
      changed_by_id: Current.user&.dig('employee_id')&.to_s,
      changed_by_name: current_user_display_name || name
    )
  end

  def record_status_change
    status_changes.create!(
      from_status: status_label_was,
      to_status: status_label,
      changed_by_id: Current.user&.dig('employee_id')&.to_s,
      changed_by_name: current_user_display_name
    )
  end

  def deliver_copy_recipients_on_submit
    deliver_copy_recipients(:submit)
  end

  # When status transitions to a terminally-approved value, fan out copies for
  # any approval-trigger recipients. Skipped for in-flight transitions and for
  # non-approval terminal states (denied/cancelled).
  def deliver_copy_recipients_on_approval
    return unless self.class.status_category_for(saved_change_to_status.last) == :approved

    deliver_copy_recipients(:approval)
  end

  def deliver_copy_recipients(event)
    template = approval_template
    return unless template.respond_to?(:copy_recipients)

    template.copy_recipients.for_event(event).ordered.each do |recipient|
      recipient.resolve_recipient_ids(self).uniq.each do |emp_id|
        next if emp_id.blank?

        FormSubmissionCopy.find_or_create_by!(
          submission_type: self.class.name,
          submission_id: id,
          recipient_employee_id: emp_id.to_i
        ) { |row| row.delivered_via = event.to_s }
      end
    end
  rescue ActiveRecord::RecordNotUnique
    # Concurrent creates race the unique index — treat as already delivered.
  end

  # When a submission lands on a routing step that resolves to nobody (e.g. the
  # submitter has no supervisor, an empty group, or no one holds the required
  # authorization for the budget unit), it would otherwise sit invisibly at
  # step_N_pending. Log it and alert the form creator + system admins so a human
  # is told. The submission is left in place (visible to admins in the inbox).
  def warn_if_no_eligible_approver(step)
    return unless step
    return if step.eligible_approver_ids(self).present?

    Rails.logger.warn(
      "No eligible approver: #{self.class.name} ##{id} stuck at step #{step.step_number} " \
      "(#{step.routing_type}#{" / #{step.authorization_service_type}" if step.routes_to_authorization?})"
    )
    StuckSubmissionMailer.no_eligible_approver(self.class.name, id, step.id).deliver_later
  rescue StandardError => e
    Rails.logger.warn("no-eligible-approver guard failed: #{e.message}")
  end

  # --- Configurable workflow emails (FormTemplateEmailStep) ---

  # Fire any "On submission" email rules right after the record is created.
  def deliver_email_steps_on_submit
    fire_email_steps('submit')
  end

  # Translate a status transition into the email rules it should fire.
  # `acted_step` is the step whose action caused the transition (derived from a
  # `step_N_pending` *from*-status). A nil step_number selects the form's final
  # approved/denied rules.
  def deliver_email_steps_on_status_change
    from_key = self.class.status_key_for(status_before_last_save)
    to_key   = self.class.status_key_for(status)
    acted_step = from_key.to_s[/\Astep_(\d+)_pending\z/, 1]&.to_i
    to_category = self.class.status_category_for(status)

    if to_category == :approved
      fire_email_steps('approved', step_number: acted_step) if acted_step
      fire_email_steps('approved', step_number: nil)
    elsif to_category == :denied
      fire_email_steps('denied', step_number: acted_step) if acted_step
      fire_email_steps('denied', step_number: nil)
    elsif acted_step && to_key.to_s.match?(/\Astep_\d+_pending\z/)
      # Advanced from one approval step to the next: the prior step was approved.
      fire_email_steps('approved', step_number: acted_step)
    end
  rescue StandardError => e
    Rails.logger.warn("TrackableStatus email dispatch failed: #{e.message}")
  end

  # Enqueue mailers for every email rule matching this event (and step, when
  # given). A nil step_number matches only final-outcome rules; omitting it
  # matches any rule for the event (used for submit).
  def fire_email_steps(event, step_number: :__any__)
    template = approval_template
    return unless template.respond_to?(:email_steps)

    rules = if step_number == :__any__
              template.email_steps.for_event(event)
            else
              template.email_steps.for_event(event, step_number: step_number)
            end

    rules.each do |email_step|
      FormWorkflowMailer.notify(email_step.id, self.class.name, id).deliver_later
    end
  rescue StandardError => e
    Rails.logger.warn("TrackableStatus fire_email_steps(#{event}) failed: #{e.message}")
  end

  def current_user_display_name
    return nil unless Current.user

    [Current.user['first_name'], Current.user['last_name']].compact.join(' ').presence
  end

  def status_label_was
    previous_status = status_before_last_save
    self.class.status_label_for(previous_status)
  end
end
