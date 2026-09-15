# frozen_string_literal: true

require 'test_helper'

class AdminToolsSidebarTest < ActionController::TestCase
  tests FormTemplatesController

  setup do
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:system_admin?) { true }
    @controller.define_singleton_method(:current_user_feature_permission_keys) do
      Set[AppFeature.permission_key('admin_tools', 'manage_forms')]
    end
    @controller.define_singleton_method(:current_user_application_permission_keys) do
      Set['admin_tools']
    end
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  test 'shows the create form action under Manage Forms' do
    template = Forms::Template.create!(name: 'Alpha Form', class_name: 'AlphaForm', page_count: 2,
                                       submission_type: 'database')

    get :edit, params: { id: template.id }

    assert_response :success
    assert_select '.admin-tools-sidebar details.nav-group[open]' do
      assert_select 'summary', text: /Manage Forms/
      assert_select 'a.nav-link', text: 'Create Form'
    end
    assert_select "a.nav-link[href='#{form_templates_path(create: true)}']", text: 'Create Form'
  end
end
