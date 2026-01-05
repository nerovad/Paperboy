# app/models/critical_information_reporting.rb

class CriticalInformationReporting < ApplicationRecord
  # ActiveStorage attachment for media files
  has_one_attached :media

  # Validations for Employee Info (Page 1)
  validates :employee_id, presence: true
  validates :name, presence: true
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
  validates :incident_manager, presence: true
  validates :reported_by, presence: true
  validates :impact_started, presence: true
  validates :location, presence: true

  # Validations for Status (Page 5)
  validates :status, presence: true, inclusion: { in: ['In Progress', 'Resolved', 'Scheduled', 'Cancelled'] }
  validates :urgency, presence: true

  # Conditional validation for actual_completion_date - only required if status is 'Resolved'
  validates :actual_completion_date, presence: true, if: -> { status == 'Resolved' }

  # Validations for Impact (Page 6)
  validates :impact, presence: true, inclusion: { in: ['Low', 'Medium', 'High'] }
  validates :impacted_customers, presence: true
  validates :next_steps, presence: true

  # Media attachment validation - optional, accepts common file types
  validate :acceptable_media_file

  private

  def acceptable_media_file
    return unless media.attached?

    unless media.blob.byte_size <= 10.megabytes
      errors.add(:media, "is too large (maximum is 10 MB)")
    end

    acceptable_types = ["image/jpeg", "image/png", "image/gif", "application/pdf"]
    unless acceptable_types.include?(media.blob.content_type)
      errors.add(:media, "must be a JPEG, PNG, GIF, or PDF")
    end
  end

  # Scopes for common queries
  scope :by_status, ->(status) { where(status: status) }
  scope :by_impact, ->(impact) { where(impact: impact) }
  scope :recent, -> { order(created_at: :desc) }
  scope :high_urgency, -> { where(urgency: '1 Immediate') }

  # Instance methods
  def resolved?
    status == 'Resolved'
  end

  def high_impact?
    impact == 'High'
  end

  def immediate_urgency?
    urgency == '1 Immediate'
  end
end
