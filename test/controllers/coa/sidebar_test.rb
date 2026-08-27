# frozen_string_literal: true

require 'test_helper'

class CoaSidebarTest < ActionController::TestCase
  tests Coa::CustomerLookupsController

  setup do
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  test 'groups every sidebar action and expands the current group' do
    get :show

    assert_response :success
    assert_select '.coa-sidebar details.nav-group', count: 3
    assert_select '.coa-sidebar details.nav-group > summary', count: 3
    assert_select '.coa-sidebar details.nav-group > summary.btn', count: 0
    assert_sidebar_group 'Lookups', ['Billing Lookup', 'Customer Lookup'], open: true
    assert_select '.coa-sidebar details.nav-group a.nav-link.active', text: 'Customer Lookup'
    assert_sidebar_group 'Budget Unit', ['Agency', 'Division', 'Department', 'Unit', 'Sub Unit']
    assert_sidebar_group 'Accounting Codes',
                         ['Activity', 'Function', 'Fund', 'Major Programs', 'Object', 'Phase',
                          'Program', 'Revenue Source', 'Object Inference', 'Task']
  end

  private

  def assert_sidebar_group(label, actions, open: false)
    assert_select '.coa-sidebar details.nav-group' do |groups|
      group = groups.find { |candidate| candidate.at_css('summary').text.strip == label }

      assert group, "expected #{label.inspect} sidebar group"
      assert_equal open, group.key?('open')
      rendered_actions = group.css('a.nav-link').map { |link| link.text.strip }
      assert_equal actions, rendered_actions
    end
  end
end
