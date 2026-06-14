class FormSubmissionCopy < ApplicationRecord
  belongs_to :submission, polymorphic: true

  # submit/approval = configured copy recipients; pool_action = the read-only
  # tracking row left for an approver who cleared a multi-approver pool step.
  DELIVERY_EVENTS = %w[submit approval pool_action].freeze

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
