# app/models/critical_information_reporting.rb

class CriticalInformationReporting < ApplicationRecord
  # Include reassignment functionality
  include Reassignable
  include TrackableStatus

enum :status, {
  in_progress: 0,
    scheduled: 1,
    resolved: 2,
    cancelled: 3
}, default: :in_progress

# Normalized status categories for cross-form reporting
STATUS_CATEGORIES = {
  in_progress: :in_review,
    scheduled: :scheduled,
    resolved: :approved,
    cancelled: :cancelled
}.freeze

# Human-readable status labels
STATUS_LABELS = {
  in_progress: "In progress",
    scheduled: "Scheduled",
    resolved: "Resolved",
    cancelled: "Cancelled"
}.freeze

  has_many_attached :media_photo_pdf_etc

  # ActiveStorage attachments for media files (multiple)

  # Callbacks
  before_validation :assign_manager_based_on_location, on: :create

  # Validations for Employee Info (Page 1)
  validates :employee_id, presence: true
  validates :name, presence: true
  validate :acceptable_media_photo_pdf_etc_files
  validates :phone, presence: true, format: { with: /\A\d{3}-\d{3}-\d{4}\z/, message: "must be in format XXX-XXX-XXXX" }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Validations for Agency Info (Page 2)
  validates :agency, presence: true
  validates :division, presence: true
  validates :department, presence: true
  validates :unit, presence: true

  # Validations for Incident Info (Page 3)
  validates :incident_type, presence: true
  validates :incident_details, presence: true
  validates :cause, presence: true

  # Validations for Incident Info Cont'd (Page 4)
  validates :staff_involved, presence: true
  validates :impact_started, presence: true
  validates :location, presence: true

  # Status enum - provides in_progress?, resolved?, etc. automatically
  # New submissions default to in_progress

  # Validations for Status (Page 5)
  validates :urgency, presence: true

  # Validations for Impact (Page 6)
  validates :impact, presence: true, inclusion: { in: ['Low', 'Medium', 'High'] }
  validates :impacted_customers, presence: true
  validates :next_steps, presence: true

  # Scopes for common queries
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_impact, ->(impact) { where(impact: impact) }
  scope :recent, -> { order(created_at: :desc) }
  scope :high_urgency, -> { where(urgency: 'Immediate') }
  scope :assigned_to, ->(manager_id) { where(assigned_manager_id: manager_id) }

  # Instance methods
  # With enum, status returns a symbol like :in_progress, :resolved, etc.
  def status_label
  self.class.const_defined?(:STATUS_LABELS) ? (self.class::STATUS_LABELS[status&.to_sym] || status&.to_s&.humanize || "Unknown") : (status&.to_s&.humanize || "Unknown")
end

  def current_assignee_id
    assigned_manager_id
  end

  def assignment_field_name
    'assigned_manager_id'
  end

  def assigned_manager_name
    employee = Employee.find_by(employee_id: assigned_manager_id)
    employee ? "#{employee.first_name} #{employee.last_name}" : nil
  end

  def acceptable_media_photo_pdf_etc_files
    return unless media_photo_pdf_etc.attached?

    if media_photo_pdf_etc.count > 10
      errors.add(:media_photo_pdf_etc, "can have a maximum of 10 files")
    end

    media_photo_pdf_etc.each do |file|
      unless file.content_type.in?(%w[image/jpeg image/png image/gif application/pdf])
        errors.add(:media_photo_pdf_etc, "must be a JPEG, PNG, GIF, or PDF")
      end

      if file.byte_size > 10.megabytes
        errors.add(:media_photo_pdf_etc, "file size must be less than 10MB")
      end
    end
  end

  private

  def assign_manager_based_on_location
    # Auto-assign the incident manager based on location
    if location.present? && assigned_manager_id.blank?
      manager_id = CriticalInformationLocationRouter.find_manager_for_location(location)
      # Skip self-assignment — submitter shouldn't also be the assigned manager
      self.assigned_manager_id = manager_id if manager_id.present? && manager_id.to_s != employee_id.to_s
    end
  end
end
