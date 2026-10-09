# frozen_string_literal: true

require 'test_helper'

# Starring a search as your Paperboy start page: the setting, the stars in the
# sidebar, and where the front door sends you.
class SearchModeStarTest < ActionController::TestCase
  EMPLOYEE_ID = 102_989

  setup do
    session[:user] = {
      'employee_id' => EMPLOYEE_ID,
      'email' => 'maria.acosta@example.com',
      'first_name' => 'Maria',
      'last_name' => 'Acosta'
    }
  end

  def sign_in
    @controller.define_singleton_method(:current_user_group_names) { Set.new }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
    @controller.define_singleton_method(:current_user_feature_permission_keys) { Set.new }
    @controller.define_singleton_method(:current_user_form_permission_keys) { Set.new(%w[leave_of_absence]) }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  def without_templates(&block)
    relation = Object.new
    relation.define_singleton_method(:includes) { |*| [] }

    Forms::Template.stub(:active, relation, &block)
  end

  def star(mode)
    UserSetting.for_employee(EMPLOYEE_ID).update!(default_search_mode: mode)
  end

  test 'starring a search stores it, and only a known search can be starred' do
    @controller = SettingsController.new
    sign_in

    patch :default_search, params: { mode: 'advanced' }
    assert_redirected_to forms_home_path
    assert_equal 'advanced', UserSetting.search_mode_for(EMPLOYEE_ID)

    patch :default_search, params: { mode: 'elsewhere' }
    assert_response :bad_request
    assert_equal 'advanced', UserSetting.search_mode_for(EMPLOYEE_ID)
  end

  test 'quick search is the start page until something else is starred' do
    assert_equal 'quick', UserSetting.search_mode_for(EMPLOYEE_ID)

    @controller = FormsController.new
    sign_in
    @request.path = '/'
    without_templates { get :home }

    assert_response :success
    assert_select '.sidebar .sidebar-star[value=advanced][aria-pressed=false]', count: 1
  end

  test 'with advanced search starred the front door opens the form library' do
    star('advanced')
    @controller = FormsController.new
    sign_in
    @request.path = '/'

    without_templates { get :home }

    assert_redirected_to form_library_path
  end

  test 'forms/home stays put so quick search can still be reached' do
    star('advanced')
    @controller = FormsController.new
    sign_in
    @request.path = '/forms/home'

    without_templates { get :home }

    assert_response :success
    assert_select '.sidebar .sidebar-star.is-starred[value=quick]', count: 1
  end

  test 'the library shows the quick search star, lit when quick is the start page' do
    @controller = FormLibraryController.new
    sign_in

    without_templates { get :index }

    assert_select '.sidebar .sidebar-star.is-starred[form=search-mode-form]', count: 1
    assert_select '.sidebar form#search-mode-form[action=?]', settings_default_search_path
  end
end
