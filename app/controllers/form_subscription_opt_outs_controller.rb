# frozen_string_literal: true

# A member stepping out of one group subscription's mail, and back in, from
# their own Settings page. They stay in the group and keep its grants; only
# this subscription stops mailing them. The subscription itself belongs to the
# group's ACL page and is never touched here.
class FormSubscriptionOptOutsController < ApplicationController
  before_action :load_subscription

  def create
    opt_out = @subscription.opt_outs.find_or_initialize_by(employee_id: current_employee_id)

    if opt_out.persisted? || opt_out.save
      redirect_to settings_path, notice: 'You will no longer be emailed about this.'
    else
      redirect_to settings_path, alert: opt_out.errors.full_messages.to_sentence
    end
  end

  def destroy
    @subscription.opt_outs.where(employee_id: current_employee_id).delete_all
    redirect_to settings_path, notice: 'You will be emailed about this again.'
  end

  private

  # Only a group subscription that reaches the signed-in user through a group
  # they belong to, so nobody can opt out of mail on someone else's behalf.
  def load_subscription
    @subscription = Forms::Subscription.reaching_member(current_employee_id)
                                       .find_by(id: params[:form_subscription_id])
    return if @subscription

    redirect_to settings_path, alert: "That subscription doesn't reach you through any of your groups."
  end

  def current_employee_id = session.dig(:user, 'employee_id').to_s
end
