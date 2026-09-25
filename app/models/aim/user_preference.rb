# frozen_string_literal: true

module Aim
  # Per-person AIM settings. Today only the mode an AIM Admin or Staff member
  # starts in: 'admin' (everything their groups allow) or 'approver' (AIM as a
  # User sees it). See Aim::AccessHelper#aim_approver_mode?.
  class UserPreference < Record
    MODES = %w[admin approver].freeze

    validates :employee_id, presence: true, uniqueness: true
    validates :start_mode, inclusion: { in: MODES }

    def self.start_mode_for(employee_id)
      return 'admin' if employee_id.blank?

      find_by(employee_id: employee_id)&.start_mode || 'admin'
    rescue ActiveRecord::ActiveRecordError
      'admin'
    end
  end
end
