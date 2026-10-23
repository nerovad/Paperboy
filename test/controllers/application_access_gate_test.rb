# frozen_string_literal: true

require 'test_helper'

# The application gate used to be copied into each namespace. These requests
# are the contract that copy had: the refusal message, the redirect, and Data
# Runner's sign-in panel staying open.
class ApplicationAccessGateTest < ActionController::TestCase
  tests ApplicationController

  USER = { 'employee_id' => 9_155_001, 'email' => 'gate@example.com', 'first_name' => 'Gate' }.freeze

  APPS = [
    [AdminTools::DashboardController, :index, 'Admin Tools'],
    [Billing::DashboardController, :index, 'Billing'],
    [Coa::ListController, :home, 'Chart of Accounts'],
    [DataRunner::DslsController, :index, 'Data Runner'],
    [Development::DashboardController, :home, 'Development'],
    [DigitalAssetManagement::DashboardController, :home, 'Digital Asset Management'],
    [HsaAdoptionCards::DashboardController, :home, 'HSA Adoption Card Search'],
    [HumanResources::DashboardController, :home, 'Human Resources'],
    [Itp::DashboardController, :home, 'IT Portal'],
    [P2m::DashboardController, :home, 'Print 2 Mail'],
    [Production::DashboardController, :index, 'Production']
  ].freeze

  test 'a signed-in user without the grant is redirected with that application message' do
    APPS.each do |controller_class, action, label|
      @controller = controller_class.new
      get action, session: { user: USER.dup }

      assert_redirected_to root_path, label
      assert_equal "You do not have access to #{label}.", flash[:alert], label
    end
  end

  test 'a signed-out visitor is refused, and Data Runner index still renders' do
    APPS.each do |controller_class, action, label|
      @controller = controller_class.new
      get action

      if label == 'Data Runner'
        assert_response :success, label
      else
        assert_redirected_to root_path, label
        assert_equal 'Please sign in to continue.', flash[:alert], label
      end
    end
  end

  test 'a signed-out visitor is refused on a Data Runner page other than the index' do
    @controller = DataRunner::LogsController.new
    get :index

    assert_redirected_to data_runner_root_path
    assert_equal 'Please sign in to continue.', flash[:alert]
  end

  test 'Production checks the print_production grant, not the word production' do
    @controller = Production::DashboardController.new
    hold @controller, 'production'
    get :index, session: { user: USER.dup }

    assert_redirected_to root_path
    assert_equal 'You do not have access to Production.', flash[:alert]
  end

  test 'holding the application grant opens the app' do
    [[Production::DashboardController, :index, 'print_production'],
     [Billing::DashboardController, :index, 'billing']].each do |controller_class, action, key|
      @controller = controller_class.new
      hold @controller, key
      get action, session: { user: USER.dup }

      assert_response :success, key
    end
  end

  private

  def hold(controller, key)
    controller.define_singleton_method(:current_user_group_names) { Set.new }
    controller.define_singleton_method(:current_user_application_permission_keys) { [key] }
    controller.define_singleton_method(:current_user_feature_permission_keys) { [] }
    controller.define_singleton_method(:current_user_dropdown_permissions) { [] }
  end
end
