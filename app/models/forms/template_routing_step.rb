# frozen_string_literal: true

module Forms
  class TemplateRoutingStep < ApplicationRecord
    self.table_name = 'form_template_routing_steps'

    def self.model_name = ActiveModel::Name.new(self, nil, 'FormTemplateRoutingStep')
    attribute :inbox_buttons, :json, default: []

    belongs_to :form_template, class_name: 'Forms::Template'

    # The routes a 'multiple' step fans out to. Empty for every other type,
    # whose single target is the step's own columns.
    has_many :routes, -> { order(:position, :id) }, class_name: 'Forms::TemplateStepRoute',
                                                    foreign_key: :form_template_routing_step_id,
                                                    inverse_of: :routing_step, dependent: :destroy

    include Forms::RouteTarget

    # 'multiple' sends the submission to every route at once; each becomes a
    # task (Forms::SubmissionStepTask) checked off on its own, and the step is
    # finished when completion_rule is met.
    MULTIPLE = 'multiple'
    ROUTING_TYPES = [*TARGET_TYPES, MULTIPLE].freeze
    CONDITION_OPERATORS = %w[equals not_equals].freeze

    # all: every route must approve. any: the first approval finishes the step.
    COMPLETION_RULES = %w[all any].freeze
    # form: one deny denies the submission there and then. task: the deny is
    # recorded on that route alone and the others still get to answer.
    DENY_RULES = %w[form task].freeze

    validates :step_number, presence: true, numericality: { greater_than: 0 }
    validates :routing_type, presence: true, inclusion: { in: ROUTING_TYPES }
    validates :step_number, uniqueness: { scope: :form_template_id }
    validates :condition_operator, inclusion: { in: CONDITION_OPERATORS }, allow_blank: true
    validates :condition_operator, presence: true, if: -> { condition_field_name.present? }
    validates :completion_rule, inclusion: { in: COMPLETION_RULES }
    validates :deny_rule, inclusion: { in: DENY_RULES }

    scope :ordered, -> { order(:step_number) }

    # Guards against double-encoded JSON the way FormTemplate#inbox_buttons does.
    def inbox_buttons
      val = super
      return [] if val.nil?

      val = JSON.parse(val) while val.is_a?(String)
      val.is_a?(Array) ? val : []
    rescue JSON::ParserError
      []
    end

    def inbox_button?(button_type)
      inbox_buttons.include?(button_type.to_s)
    end

    # Text for the inbox Approve button at this step. An optional per-step
    # override (e.g. "Permit Printed") that still performs the normal approve
    # action; blank falls back to the default "Approve".
    def approve_button_text
      approve_button_label.presence || 'Approve'
    end

    # Text for the inbox Deny button at this step, with the same override
    # semantics as approve_button_text.
    def deny_button_text
      deny_button_label.presence || 'Deny'
    end

    def multiple?
      routing_type == MULTIPLE
    end

    def routing_label
      return routes.map(&:target_label).to_sentence if multiple?

      target_label
    end

    # Default display name for the pending status at this step
    def default_pending_display_name
      "Sent to #{routing_label}"
    end

    # Default display name for the approved status at this step
    def default_approved_display_name
      "#{routing_label} Approved"
    end

    # Pending display name: prefer user-set display_name, fall back to default
    def pending_display_name
      display_name.presence || default_pending_display_name
    end

    # Approved display name: derive from display_name or fall back to default
    def approved_display_name
      default_approved_display_name
    end

    # True when this step has a condition that gates whether it runs.
    def conditional?
      condition_field_name.present? && condition_operator.present?
    end

    # The form field this step's condition checks. Looked up by stable
    # field_name so it survives form-field rebuilds that renumber ids; falls
    # back to the model's condition-only fields.
    def condition_field
      return nil unless condition_field_name.present?

      form_template.form_fields.find_by(field_name: condition_field_name) ||
        form_template.routing_condition_fields.find { |f| f.field_name == condition_field_name }
    end

    # Evaluates the condition against a submitted form record.
    # Returns true when the step has no condition or the condition matches; false otherwise.
    # A multi-value answer (an array) "equals" the value when it contains it.
    def matches?(form_record)
      return true unless conditional?

      actual = form_record.respond_to?(condition_field_name) ? form_record.public_send(condition_field_name) : nil
      hit = if actual.is_a?(Array)
              actual.map(&:to_s).include?(condition_value.to_s)
            else
              actual.to_s == condition_value.to_s
            end

      case condition_operator
      when 'equals' then hit
      when 'not_equals' then !hit
      else true
      end
    end

    # The concrete employee_ids that could act on `submission` at this step.
    # Centralizes the per-type resolution so the runtime guard (and anyone else)
    # can tell when a step would route to nobody. Mirrors how approver_id is set
    # in TrackableStatus and how the inbox surfaces group/authorization steps.
    #
    # A multi-route step answers with whoever still owes a task: someone whose
    # task is closed is no longer an approver here, though the step is open.
    def eligible_approver_ids(submission)
      return target_approver_ids(submission) unless multiple?

      tasks = step_tasks_for(submission)
      return routes.flat_map { |route| route.target_approver_ids(submission) }.uniq if tasks.empty?

      tasks.select(&:pending?).flat_map { |task| task.eligible_approver_ids(submission) }.uniq
    rescue StandardError
      []
    end

    # True when `submission`, sitting at this step, has work nobody can pick
    # up: the step's target resolves to no one, or one of its routes does.
    def unstaffed?(submission)
      return eligible_approver_ids(submission).blank? unless multiple?

      tasks = step_tasks_for(submission).select(&:pending?)
      tasks.empty? || tasks.any? { |task| task.eligible_approver_ids(submission).blank? }
    end

    # Human-readable summary of the condition for badges/display.
    def condition_label
      return nil unless conditional?

      field = condition_field
      return nil unless field

      op = condition_operator == 'not_equals' ? '≠' : '='
      %(Only if "#{field.label}" #{op} "#{condition_value}")
    end

    private

    # The tasks `submission` carries for this step, in any state. Empty for a
    # submission that has never stood here.
    def step_tasks_for(submission)
      return [] unless submission.respond_to?(:step_tasks) && submission.persisted?

      submission.step_tasks.where(step_number: step_number).to_a
    end
  end
end
