# frozen_string_literal: true

require 'test_helper'

# Opting out of a group subscription from Settings: only the signed-in member,
# only for a group they are in, and never for a required subscription.
class FormSubscriptionOptOutsControllerTest < ActionController::TestCase
  CIR = 'CriticalInformationReporting'

  setup do
    session[:user] = { 'employee_id' => 7201, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    EmployeeGroup.insert_all([{ GroupID: 4260, EmployeeID: 7201 }])
    @subscription = group_subscription(4260)
  end

  def group_subscription(group_id, **overrides)
    Forms::Subscription.create!({ form_type: CIR, grantee_type: 'group', group_id: group_id,
                                  notify_created: true }.merge(overrides))
  end

  test 'a member opts out without leaving the group' do
    post :create, params: { form_subscription_id: @subscription.id }

    assert_redirected_to settings_path
    assert @subscription.opt_outs.exists?(employee_id: '7201')
    assert EmployeeGroup.exists?(GroupID: 4260, EmployeeID: 7201)
    assert_empty Forms::Subscription.expand_recipients([@subscription])
  end

  test 'opting out twice is harmless' do
    2.times { post :create, params: { form_subscription_id: @subscription.id } }

    assert_equal 1, @subscription.opt_outs.count
  end

  test 'a member opts back in' do
    @subscription.opt_outs.create!(employee_id: '7201')

    delete :destroy, params: { form_subscription_id: @subscription.id }

    assert_redirected_to settings_path
    assert_not @subscription.opt_outs.exists?
  end

  test 'a required subscription refuses the opt-out' do
    required = group_subscription(4260, form_type: 'SafetyReport', required: true)

    post :create, params: { form_subscription_id: required.id }

    assert_redirected_to settings_path
    assert_not required.opt_outs.exists?
    assert_match(/required/, flash[:alert])
  end

  test 'a group the user is not in cannot be opted out of' do
    elsewhere = group_subscription(4261)

    post :create, params: { form_subscription_id: elsewhere.id }

    assert_redirected_to settings_path
    assert_not elsewhere.opt_outs.exists?
  end
end
