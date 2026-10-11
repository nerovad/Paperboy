# frozen_string_literal: true

require 'test_helper'

# Taking a form off your own sidebar and putting it back: the setting, the
# sidebar that honours it, and the Form Library rows that change it.
class SidebarHiddenFormsTest < ActionController::TestCase
  EMPLOYEE_ID = 102_989

  setup do
    session[:user] = {
      'employee_id' => EMPLOYEE_ID,
      'email' => 'maria.acosta@example.com',
      'first_name' => 'Maria',
      'last_name' => 'Acosta'
    }
  end

  def sign_in(forms: %w[leave_of_absence notice_of_change])
    @controller.define_singleton_method(:current_user_group_names) { Set.new }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
    @controller.define_singleton_method(:current_user_feature_permission_keys) { Set.new }
    @controller.define_singleton_method(:current_user_form_permission_keys) { Set.new(forms) }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  def without_templates(&block)
    relation = Object.new
    relation.define_singleton_method(:includes) { |*| [] }

    Forms::Template.stub(:active, relation, &block)
  end

  def hide(*keys)
    UserSetting.for_employee(EMPLOYEE_ID).update!(hidden_form_keys: keys)
  end

  test 'hiding a form stores it, and showing it again removes it' do
    @controller = SettingsController.new
    sign_in

    without_templates { patch :sidebar_form, params: { form_key: 'leave_of_absence', hidden: '1' } }
    assert_redirected_to form_library_path
    assert_equal %w[leave_of_absence], UserSetting.hidden_form_keys_for(EMPLOYEE_ID)

    without_templates { patch :sidebar_form, params: { form_key: 'leave_of_absence', hidden: '0' } }
    assert_empty UserSetting.hidden_form_keys_for(EMPLOYEE_ID)
  end

  test 'a form the viewer may not open cannot be named' do
    @controller = SettingsController.new
    sign_in

    without_templates { patch :sidebar_form, params: { form_key: 'workplace_violence', hidden: '1' } }

    assert_response :bad_request
    assert_empty UserSetting.hidden_form_keys_for(EMPLOYEE_ID)
  end

  test 'the sidebar keeps a hidden form out of sight and offers to show it' do
    @controller = FormsController.new
    sign_in
    hide('leave_of_absence')

    without_templates { get :home }

    assert_select '.sidebar a.nav-link[data-user-hidden=true][style*=?]', 'display: none', text: 'Leave of Absence'
    assert_select '.sidebar a.nav-link:not([data-user-hidden])', text: 'Notice of Change'
    assert_select '.sidebar label.sidebar-show-hidden[hidden]', text: /Show Hidden Forms \(1\)/
  end

  test 'with nothing hidden the sidebar offers no such option' do
    @controller = FormsController.new
    sign_in

    without_templates { get :home }

    assert_select '.sidebar a.nav-link[data-user-hidden]', count: 0
    assert_select '.sidebar-show-hidden', count: 0
  end

  test 'the library still lists a hidden form and offers to put it back' do
    @controller = FormLibraryController.new
    sign_in
    hide('leave_of_absence')

    without_templates { get :index }

    assert_select '.form-library__row', count: 2
    assert_select '.form-library__hidden', count: 1
    assert_select '.form-library__row-actions button', text: 'Show in sidebar', count: 1
    assert_select '.form-library__row-actions button', text: 'Hide from sidebar', count: 1
  end
end
