# frozen_string_literal: true

# One member stepping out of one group subscription's mail.
#
# The member stays in the group and keeps every grant the group gives; only
# this subscription stops mailing them. Opt-outs are per subscription row, so
# somebody in two groups that both follow a form opts out of each separately.
# A +required+ subscription cannot be opted out of, and one made required after
# the fact ignores any opt-out already recorded against it.
module Forms
  class SubscriptionOptOut < ApplicationRecord
    self.table_name = 'form_subscription_opt_outs'

    def self.model_name = ActiveModel::Name.new(self, nil, 'FormSubscriptionOptOut')

    belongs_to :subscription, class_name: 'Forms::Subscription',
                              foreign_key: :form_subscription_id, inverse_of: :opt_outs

    validates :employee_id, presence: true, uniqueness: { scope: :form_subscription_id }
    validate :subscription_is_optional

    # subscription id => the employee ids opted out of it.
    def self.employee_ids_by_subscription(subscription_ids)
      return {} if subscription_ids.blank?

      where(form_subscription_id: subscription_ids)
        .pluck(:form_subscription_id, :employee_id)
        .group_by(&:first)
        .transform_values { |pairs| pairs.map { |_id, employee_id| employee_id.to_s } }
    end

    private

    def subscription_is_optional
      return if subscription.nil? || subscription.opt_out_allowed?

      errors.add(:base, 'This subscription is required and cannot be opted out of')
    end
  end
end
