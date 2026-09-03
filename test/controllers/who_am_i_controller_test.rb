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

  test 'show renders the hierarchy card inside the dialog frame' do
    nodes = [{ level: 'Agency', id: 'HCA', name: 'Health Care Agency' }]

    stub_employee(nodes) { get :show }

    assert_response :success
    assert_select 'turbo-frame#who_am_i', count: 1
    assert_select '[data-controller=?]', 'coa-account-hierarchy', count: 1
    assert_select '[data-coa-account-hierarchy-nodes-value]', count: 1
  end

  # The layout renders the dialog on every page, and that dialog holds the
  # frame this response fills. Sending the layout back would hand Turbo two
  # frames of the same name and it would fill the placeholder with itself.
  test 'show renders without the layout' do
    stub_employee { get :show }

    assert_select 'div.sidebar', count: 0
    assert_select '.work-tabs', count: 0
  end

  test 'show reports a missing employee record inside the frame' do
    Employee.stub(:find_by!, ->(*) { raise ActiveRecord::RecordNotFound }) do
      get :show
    end

    assert_response :success
    assert_select 'turbo-frame#who_am_i', text: /Employee record not found/
  end

  test 'show refuses signed-out visitors' do
    session.delete(:user)

    get :show

    assert_response :forbidden
  end

  private

  def stub_employee(nodes = [], &block)
    employee = Struct.new(:employee_id, :first_name, :last_name)
                     .new(102_989, 'Maria', 'Acosta')

    Employee.stub(:find_by!, employee) do
      Coa::EmployeeHierarchy.stub(:call, nodes, &block)
    end
  end
end
