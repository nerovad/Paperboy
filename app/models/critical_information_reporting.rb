# app/models/critical_information_reporting.rb

class CriticalInformationReporting < ApplicationRecord
  # ActiveStorage attachment for media files
  has_one_attached :media

  # Callbacks
  before_validation :assign_manager_based_on_location, on: :create

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
  validates :impact_started, presence: true
  validates :location, presence: true

  # Status enum - provides in_progress?, resolved?, etc. automatically
  # New submissions default to in_progress
  enum :status, {
    in_progress: 0,
    resolved: 1,
    scheduled: 2,
    cancelled: 3
  }, default: :in_progress

  # Validations for Status (Page 5)
  validates :urgency, presence: true

  # Validations for Impact (Page 6)
  validates :impact, presence: true, inclusion: { in: ['Low', 'Medium', 'High'] }
  validates :impacted_customers, presence: true
  validates :next_steps, presence: true

  # Media attachment validation - optional, accepts common file types
  validate :acceptable_media_file

  # Scopes for common queries
  scope :for_employee, ->(employee_id) { where(employee_id: employee_id.to_s) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_impact, ->(impact) { where(impact: impact) }
  scope :recent, -> { order(created_at: :desc) }
  scope :high_urgency, -> { where(urgency: '1 Immediate') }
  scope :assigned_to, ->(manager_id) { where(assigned_manager_id: manager_id) }

  # Instance methods
  # With enum, status returns a symbol like :in_progress, :resolved, etc.
  def status_label
    status&.to_s&.humanize || "Unknown"
  end

  def high_impact?
    impact == 'High'
  end

  def immediate_urgency?
    urgency == '1 Immediate'
  end

  # Get the Employee record for the assigned manager
  def assigned_manager
    return nil unless assigned_manager_id.present?
    @assigned_manager ||= Employee.find_by(EmployeeID: assigned_manager_id)
  end

  def assigned_manager_name
    assigned_manager&.then { |e| "#{e['First_Name']} #{e['Last_Name']}" } || "Unassigned"
  end

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

  def assign_manager_based_on_location
    # Auto-assign the incident manager based on location
    if location.present? && assigned_manager_id.blank?
      manager_id = CriticalInformationLocationRouter.find_manager_for_location(location)
      self.assigned_manager_id = manager_id if manager_id.present?
    end
  end
end
