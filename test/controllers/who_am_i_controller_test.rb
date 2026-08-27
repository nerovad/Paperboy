# frozen_string_literal: true

require 'test_helper'

class WhoAmIControllerTest < ActionController::TestCase
  tests WhoAmIController

  setup do
    session[:user] = {
      'employee_id' => 102_989,
      'email' => 'maria.acosta@example.com',
      'first_name' => 'Maria',
      'last_name' => 'Acosta'
    }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  test 'show renders the shared hierarchy card for the signed-in employee' do
    employee = Struct.new(:employee_id, :first_name, :last_name)
                     .new(102_989, 'Maria', 'Acosta')
    nodes = [{ level: 'Agency', id: 'HCA', name: 'Health Care Agency' }]

    Employee.stub(:find_by!, employee) do
      Coa::EmployeeHierarchy.stub(:call, nodes) do
        get :show
      end
    end

    assert_response :success
    assert_select 'h1', text: 'Who Am I'
    assert_select '.work-tab--who-am-i.is-active', text: 'Who Am I'
    assert_select '.sidebar a[href=?]', who_am_i_path, count: 0
    assert_select '[data-controller=?]', 'coa-account-hierarchy', count: 1
    assert_select '[data-coa-account-hierarchy-nodes-value]', count: 1
  end

  test 'show redirects signed-out visitors' do
    session.delete(:user)

    get :show

    assert_redirected_to root_path
  end
end
