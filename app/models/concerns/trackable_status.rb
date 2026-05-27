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
    after_update :record_status_change, if: :saved_change_to_status?
    after_update :deliver_copy_recipients_on_approval, if: :saved_change_to_status?
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

      key ? key.humanize : "Unknown"
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
        pending: "Pending",
        in_review: "In Review",
        approved: "Approved",
        denied: "Denied",
        cancelled: "Cancelled",
        scheduled: "Scheduled"
      }
    end
  end

  def status_timeline
    status_changes.chronological
  end

  # Starts a multi-step approval flow from the first step whose condition
  # matches the submitted form. If no step matches, marks the form approved
  # immediately (treated as a no-op approval).
  def start_approval!
    template = approval_template
    return unless template

    steps = template.routing_steps.ordered.to_a
    return if steps.empty?

    first_step = steps.find { |s| s.matches?(self) }
    return approved! unless first_step

    update!(
      status: "step_#{first_step.step_number}_pending",
      approver_id: approver_id_for_routing_step(first_step)
    )
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

    update!(
      status: "step_#{next_step.step_number}_pending",
      approver_id: approver_id_for_routing_step(next_step)
    )
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
    self.class.category_labels[status_category] || "Unknown"
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
    return unless self.class.column_names.include?("approver_id")
    return unless TERMINAL_STATUSES.include?(status.to_s)

    actor_id = Current.user&.dig("employee_id")&.to_s.presence
    return unless actor_id
    return if approver_id.to_s == actor_id

    update_columns(approver_id: actor_id)
  end

  def approval_template
    respond_to?(:form_template) ? form_template : nil
  rescue
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
    when 'group'
      nil
    end
  end

  def submitter_employee
    return nil unless respond_to?(:employee_id) && employee_id.present?
    Employee.find_by(employee_id: employee_id)
  end

  def record_initial_status
    status_changes.create!(
      from_status: nil,
      to_status: status_label,
      changed_by_id: Current.user&.dig("employee_id")&.to_s,
      changed_by_name: current_user_display_name || name
    )
  end

  def record_status_change
    status_changes.create!(
      from_status: status_label_was,
      to_status: status_label,
      changed_by_id: Current.user&.dig("employee_id")&.to_s,
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
    return unless template&.respond_to?(:copy_recipients)
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

  def current_user_display_name
    return nil unless Current.user
    [Current.user["first_name"], Current.user["last_name"]].compact.join(" ").presence
  end

  def status_label_was
    previous_status = status_before_last_save
    self.class.status_label_for(previous_status)
  end
end
