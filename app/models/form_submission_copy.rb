class FormSubmissionCopy < ApplicationRecord
  belongs_to :submission, polymorphic: true

  DELIVERY_EVENTS = %w[submit approval].freeze

  validates :recipient_employee_id, presence: true
  validates :delivered_via, presence: true, inclusion: { in: DELIVERY_EVENTS }
  validates :submission_id,
            uniqueness: { scope: [:submission_type, :recipient_employee_id] }

  scope :active, -> { where(dismissed_at: nil) }
  scope :for_recipient, ->(employee_ids) { where(recipient_employee_id: employee_ids) }

  def dismissed?
    dismissed_at.present?
  end

  def dismiss!
    update!(dismissed_at: Time.current) unless dismissed?
  end
end
