# frozen_string_literal: true

module Aim
  # The high-dollar second approval (#131). An invoice over its budget unit's
  # amount (Aim::BudgetUnitSetting) is not finished by its first approval: the
  # first approval is kept on the invoice and it moves to the second
  # approver's queue, still Ready for Approval. Their approval finishes it;
  # they may return it to the first approver. One approval is enough when the
  # first approver is the second approver. Leaving Ready for Approval any way
  # but approval forgets the first approval. Included by Aim::Invoice.
  module InvoiceSecondApproval
    extend ActiveSupport::Concern

    APPROVED_ONWARD = %w[ready_for_approval approved exporting exported].freeze

    included do
      before_save :forget_first_approval, if: -> { state_changed? && APPROVED_ONWARD.exclude?(state) }
    end

    def second_approval_setting
      @second_approval_setting ||= Aim::BudgetUnitSetting.for_unit(agency!, budget_unit)
    end

    def awaiting_second_approval? = state == 'ready_for_approval' && first_approved_by.present?

    # Whether approving now, by +employee_id+, is only the first of two.
    def needs_second_approval?(employee_id)
      setting = second_approval_setting
      return false unless setting&.second_approval? && invoice_total.present?
      return false if awaiting_second_approval? || setting.second_approver_employee_id == employee_id.to_i

      invoice_total > setting.second_approval_over
    end

    # Whether +employee_id+ may give the second approval: the second approver,
    # or AIM staff (+staff+).
    def second_approver?(employee_id, staff: false)
      staff || second_approval_setting&.second_approver_employee_id == employee_id.to_i
    end

    def first_approve!(actor:, by:)
      setting = second_approval_setting
      transaction do
        update!(first_approved_by: actor, first_approved_at: Time.current)
        events.create!(action: 'approval', actor: actor, from_state: state, to_state: state,
                       note: "First approval. Over #{format('$%.2f', setting.second_approval_over)}: " \
                             "to #{setting.second_approver_name} for a second approval")
        reassign!(setting.second_approver_employee_id.to_s, actor: actor, by: by)
      end
    end

    # Back to whoever gave the first approval, for another look.
    def return_to_first_approver!(actor:, reason:, by:)
      first = Employee.find_by(email: first_approved_by)
      transaction do
        update!(first_approved_by: nil, first_approved_at: nil)
        events.create!(action: 'approval', actor: actor, from_state: state, to_state: state,
                       note: "Returned to the first approver: #{reason}")
        reassign!(first&.id.to_s, actor: actor, by: by)
      end
    end

    private

    def forget_first_approval
      self.first_approved_by = nil
      self.first_approved_at = nil
    end
  end
end
