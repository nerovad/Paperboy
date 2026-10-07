# frozen_string_literal: true

module Forms
  class SubmissionCopy < ApplicationRecord
    self.table_name = 'form_submission_copies'

    def self.model_name = ActiveModel::Name.new(self, nil, 'FormSubmissionCopy')
    belongs_to :submission, polymorphic: true

    # submit/approval = configured copy recipients. pool_action rows are no
    # longer written: they kept a form in the inbox of an approver who had
    # cleared a pool step, and Submissions lists what someone acted on instead.
    # The value stays valid for the rows already stored.
    DELIVERY_EVENTS = %w[submit approval pool_action].freeze

    validates :recipient_employee_id, presence: true
    validates :delivered_via, presence: true, inclusion: { in: DELIVERY_EVENTS }
    validates :submission_id,
              uniqueness: { scope: %i[submission_type recipient_employee_id] }

    scope :active, -> { where(dismissed_at: nil) }
    scope :for_recipient, ->(employee_ids) { where(recipient_employee_id: employee_ids) }

    def dismissed?
      dismissed_at.present?
    end

    def dismiss!
      update!(dismissed_at: Time.current) unless dismissed?
    end
  end
end
