class FormTemplate < ApplicationRecord
  attribute :page_headers, :json
  attribute :inbox_buttons, :json, default: []

  # Ensure page_headers always returns an array (guards against double-encoded JSON)
  def page_headers
    val = super
    return nil if val.nil?
    val = JSON.parse(val) while val.is_a?(String)
    val.is_a?(Array) ? val : nil
  rescue JSON::ParserError
    nil
  end

  # Ensure inbox_buttons always returns an array (guards against double-encoded JSON)
  def inbox_buttons
    val = super
    return [] if val.nil?
    val = JSON.parse(val) while val.is_a?(String)
    val.is_a?(Array) ? val : []
  rescue JSON::ParserError
    []
  end

  # Virtual attribute to track routing steps being submitted (before they're saved)
  attr_accessor :pending_routing_steps

  # Tags for metadata search
  def tags_array
    (tags || "").split(",").map(&:strip).reject(&:blank?)
  end

  def tags_array=(array)
    self.tags = Array(array).map(&:strip).reject(&:blank?).join(",")
  end

  # Get all unique tags used across all form templates
  def self.all_tags
    FormTemplate.pluck(:tags)
                .compact
                .flat_map { |t| t.split(",").map(&:strip) }
                .reject(&:blank?)
                .uniq
                .sort
  end

  # Available inbox button types
  INBOX_BUTTON_TYPES = {
    'view_pdf' => { label: 'View PDF', description: 'Download or view the form as PDF' },
    'edit' => { label: 'Edit', description: 'Edit the submitted form' },
    'approve' => { label: 'Approve', description: 'Approve button for approval workflows' },
    'deny' => { label: 'Deny', description: 'Deny button with reason modal' },
    'reassign' => { label: 'Reassign', description: 'Reassign to another employee' },
    'take_back' => { label: 'Take Back', description: 'Take back a reassigned task' },
    'status_dropdown' => { label: 'Status Dropdown', description: 'Quick status change dropdown' }
  }.freeze

  has_many :form_fields, dependent: :destroy
  has_many :routing_steps, -> { order(:step_number) }, class_name: 'FormTemplateRoutingStep', dependent: :destroy
  has_many :statuses, -> { order(:position) }, class_name: 'FormTemplateStatus', dependent: :destroy
  accepts_nested_attributes_for :routing_steps, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :statuses, allow_destroy: true, reject_if: :all_blank

  TRANSITION_MODES = %w[automatic manual].freeze

  validates :name, presence: true
  validates :class_name, presence: true, uniqueness: true
  validates :page_count, numericality: { greater_than_or_equal_to: 2, less_than_or_equal_to: 30 }
  validates :visibility, inclusion: { in: %w[public restricted] }
  validates :submission_type, inclusion: { in: %w[database approval] }
  validates :approval_routing_to, presence: true, if: :requires_legacy_routing?
  validates :approval_employee_id, presence: true, if: :routes_to_specific_employee?
  validates :powerbi_workspace_id, presence: true, if: :has_dashboard?
  validates :powerbi_report_id, presence: true, if: :has_dashboard?
  validates :status_transition_mode, inclusion: { in: TRANSITION_MODES }, allow_nil: true

  validate :page_count_cannot_orphan_fields, on: :update
  validate :approval_must_have_terminal_statuses

  before_validation :generate_class_name, on: :create

  scope :with_dashboards, -> { where(has_dashboard: true) }
  
  def requires_approval?
    submission_type == 'approval'
  end

  def routes_to_specific_employee?
    requires_approval? && approval_routing_to == 'employee'
  end

  def requires_legacy_routing?
    requires_approval? && !has_routing_steps?
  end

  def has_routing_steps?
    routing_steps.any? || pending_routing_steps.present?
  end

  def has_multiple_routing_steps?
    routing_steps.count > 1
  end

  def has_dashboard?
    has_dashboard == true
  end

  def automatic_status_transitions?
    status_transition_mode == 'automatic'
  end

  def manual_status_transitions?
    status_transition_mode == 'manual'
  end

  def has_inbox_button?(button_type)
    (inbox_buttons || []).include?(button_type.to_s)
  end

  def enabled_inbox_buttons
    inbox_buttons || []
  end
  
  def table_name
    class_name.underscore.pluralize
  end
  
  def file_name
    class_name.underscore
  end
  
  def plural_file_name
    file_name.pluralize
  end
  
  def page_header(page_num)
    return "Employee Info" if page_num == 1
    return "Agency Info" if page_num == 2
    
    headers = page_headers || []
    headers[page_num - 3]
  end
  
  private

  def generate_class_name
    return if name.blank?

    self.class_name = name.gsub(/[^a-zA-Z0-9\s]/, '').split.map(&:capitalize).join + 'Form'
  end

  def approval_must_have_terminal_statuses
    return unless requires_approval?
    return unless statuses.user_configured.any?

    has_approved = statuses.user_configured.any? { |s| s.category == 'approved' }
    has_denied = statuses.user_configured.any? { |s| s.category == 'denied' }

    errors.add(:base, "Approval forms must have at least one status with the 'Approved' category") unless has_approved
    errors.add(:base, "Approval forms must have at least one status with the 'Denied' category") unless has_denied
  end

  def page_count_cannot_orphan_fields
    return unless page_count_changed? && page_count_was.present?

    if page_count < page_count_was
      max_field_page = form_fields.maximum(:page_number)
      if max_field_page && max_field_page > page_count
        errors.add(:page_count,
          "cannot be reduced to #{page_count} because fields exist on page #{max_field_page}. " \
          "Please remove or move fields first.")
      end
    end
  end
end
