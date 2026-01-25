class FormTemplateStatus < ApplicationRecord
  belongs_to :form_template

  # Valid categories (must match TrackableStatus::VALID_CATEGORIES)
  VALID_CATEGORIES = %w[pending in_review approved denied cancelled scheduled].freeze

  # Predefined statuses with their default category mappings
  # These are the common statuses that users can select from
  PREDEFINED_STATUSES = [
    { name: 'Submitted', key: 'submitted', category: 'pending', is_initial: true, is_terminal: false },
    { name: 'In Progress', key: 'in_progress', category: 'in_review', is_initial: true, is_terminal: false },
    { name: 'Pending Approval', key: 'pending_approval', category: 'in_review', is_initial: false, is_terminal: false },
    { name: 'Approved', key: 'approved', category: 'approved', is_initial: false, is_terminal: true },
    { name: 'Denied', key: 'denied', category: 'denied', is_initial: false, is_terminal: true },
    { name: 'Cancelled', key: 'cancelled', category: 'cancelled', is_initial: false, is_terminal: true },
    { name: 'Scheduled', key: 'scheduled', category: 'scheduled', is_initial: false, is_terminal: false },
    { name: 'Resolved', key: 'resolved', category: 'approved', is_initial: false, is_terminal: true },
    { name: 'Sent to Security', key: 'sent_to_security', category: 'in_review', is_initial: false, is_terminal: false },
    { name: 'Sent to HR', key: 'sent_to_hr', category: 'in_review', is_initial: false, is_terminal: false }
  ].freeze

  # Validations
  validates :name, presence: true
  validates :key, presence: true, uniqueness: { scope: :form_template_id }
  validates :category, presence: true, inclusion: { in: VALID_CATEGORIES }
  validates :position, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :ordered, -> { order(:position) }
  scope :initial, -> { where(is_initial: true) }
  scope :terminal, -> { where(is_terminal: true) }

  # Before validation callback to generate key from name if not provided
  before_validation :generate_key_from_name, if: -> { key.blank? && name.present? }

  # Class method to get predefined status by key
  def self.predefined_status(key)
    PREDEFINED_STATUSES.find { |s| s[:key] == key.to_s }
  end

  # Class method to get all predefined status keys
  def self.predefined_keys
    PREDEFINED_STATUSES.map { |s| s[:key] }
  end

  # Check if this status is a predefined one
  def predefined?
    self.class.predefined_keys.include?(key)
  end

  # Get the human-readable category label
  def category_label
    {
      'pending' => 'Pending',
      'in_review' => 'In Review',
      'approved' => 'Approved',
      'denied' => 'Denied',
      'cancelled' => 'Cancelled',
      'scheduled' => 'Scheduled'
    }[category] || category.titleize
  end

  private

  def generate_key_from_name
    self.key = name.parameterize.underscore
  end
end
