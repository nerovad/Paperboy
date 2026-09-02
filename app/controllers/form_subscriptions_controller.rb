# frozen_string_literal: true

# Add and remove form subscriptions — the rows behind two screens that manage
# the same table from opposite ends. A group's ACL page (acl/_form_subscriptions)
# subscribes a whole group and is admin-only; the Settings page
# (settings/_form_subscriptions) subscribes the signed-in user to their own mail
# and needs nothing beyond being signed in.
#
# There is no index: each screen lists the rows it owns, and is where both
# actions return.
class FormSubscriptionsController < ApplicationController
  # Group rows are an ACL concern; personal rows are the user's own business.
  # Guarding on what the request actually targets keeps one controller honest
  # for both screens, including a hand-posted group_id from the Settings form.
  before_action :require_group_admin!, if: :group_scoped?

  def create
    subscription = Forms::Subscription.new(subscription_attributes)

    if subscription.form_type.blank?
      redirect_back_with(alert: 'Pick a form.')
    elsif subscription.save
      redirect_back_with(notice: 'Subscription added.')
    else
      redirect_back_with(alert: subscription.errors.full_messages.to_sentence.presence || 'Could not subscribe.')
    end
  end

  def destroy
    subscription = Forms::Subscription.find(params[:id])

    # A personal subscription can only be removed by the person it mails.
    return redirect_back_with(alert: "That isn't your subscription.") if personal_subscription_of_someone_else?(subscription)

    @group_id = subscription.group_id
    subscription.destroy
    redirect_back_with(notice: 'Subscription removed.')
  end

  private

  # True when this request touches a group's subscriptions rather than the
  # signed-in user's own — either because the form posted a group, or because
  # the row being destroyed belongs to one.
  def group_scoped?
    return true if params[:group_id].present?

    action_name == 'destroy' &&
      Forms::Subscription.where(id: params[:id]).pick(:grantee_type) == 'group'
  end

  def require_group_admin! = require_admin_tab('acl')

  def personal_subscription_of_someone_else?(subscription)
    subscription.grantee_type == 'employee' && subscription.employee_id.to_s != current_employee_id
  end

  def current_employee_id = session.dig(:user, 'employee_id').to_s

  def subscription_attributes
    permitted = params.permit(:form_type, :group_id, :delivery_mode, events: [])

    base = {
      form_type: permitted[:form_type].to_s,
      delivery_mode: permitted[:delivery_mode].presence || Forms::Subscription::IMMEDIATE
    }.merge(event_flags(Array(permitted[:events]).map(&:to_s)))

    if permitted[:group_id].present?
      base.merge(grantee_type: 'group', group_id: permitted[:group_id])
    else
      base.merge(grantee_type: 'employee', employee_id: current_employee_id)
    end
  end

  # Checked boxes arrive as event names; the model stores one boolean column
  # each. Unchecked events are written false rather than omitted so the hash is
  # a complete picture of the row.
  def event_flags(events)
    Forms::Subscription::EVENT_COLUMNS.each_with_object({}) do |(event, column), flags|
      flags[column] = events.include?(event)
    end
  end

  def redirect_back_with(**flash_args)
    target = params[:group_id].presence || @group_id
    path = target.present? ? permissions_acl_path(target) : settings_path
    redirect_to path, **flash_args
  end
end
