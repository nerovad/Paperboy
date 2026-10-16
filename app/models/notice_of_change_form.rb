# frozen_string_literal: true

class NoticeOfChangeForm < ApplicationRecord
  include TrackableStatus

  enum :status, {
    in_progress: 'in_progress',
    step_1_pending: 'step_1_pending',
    approved: 'approved',
    denied: 'denied',
    cancelled: 'cancelled'
  }, default: :in_progress

  scope :for_employee, ->(employee_id) { where(employee_id: employee_id) }

  validates :name, :email, presence: true

  def form_template
    @form_template ||= Forms::Template.find_by(class_name: self.class.name)
  end
end
