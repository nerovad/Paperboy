# frozen_string_literal: true

require 'test_helper'

class ProductionSidebarTest < ActionController::TestCase
  tests Production::DashboardController

  setup do
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  test 'groups production links and expands only Paperboy environments' do
    get :index

    assert_response :success
    assert_select '.production-sidebar details.nav-group', count: 5
    assert_sidebar_group 'Paperboy Environments', %w[Production Staging Development], open: true
    assert_sidebar_group 'Production Systems',
                         ['Creative Service Lookbook', 'DocuShare', 'Impress Automate',
                          'Legacy e-Forms', 'USPS Gateway', 'VCPrint']
    assert_sidebar_group 'Projects & Support', ['Asana', 'Gitea', 'GSA Service Desk']
    assert_sidebar_group 'Finance & Operations',
                         ['ACO', 'CalSAWS', 'Legacy PSI:Fusion', 'Purchase Order Status', 'VCFMS']
    assert_sidebar_group 'Employee & Facilities',
                         %w[MainStar MyVCWeb TargetSolutions VCHRP VCLearning VCWorkplace]
    assert_select '.production-sidebar a.nav-link[target="_blank"][rel="noopener"]', count: 23
  end

  private

  def assert_sidebar_group(label, actions, open: false)
    assert_select '.production-sidebar details.nav-group' do |groups|
      group = groups.find { |candidate| candidate.at_css('summary').text.strip == label }

      assert group, "expected #{label.inspect} sidebar group"
      assert_equal open, group.key?('open')
      rendered_actions = group.css('a.nav-link').map { |link| link.text.strip }
      assert_equal actions, rendered_actions
    end
  end
end
