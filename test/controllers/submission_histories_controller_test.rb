# frozen_string_literal: true

require 'test_helper'

# The on-demand history fragments the inbox modal fetches. Edit History is not a
# configurable button -- it rides along with Edit -- so the endpoint carries the
# whole access decision, and that is what these cover.
class SubmissionHistoriesControllerTest < ActionController::TestCase
  tests SubmissionHistoriesController

  setup do
    @record = probation_transfer_requests(:one)
    session[:user] = { 'employee_id' => '9999', 'email' => 'viewer@example.com',
                       'first_name' => 'Dana', 'last_name' => 'Reyes' }
    @controller.define_singleton_method(:inbox_count) { 0 }
    permit_nothing
  end

  # The fixture is filed by 'MyString' and assigned to nobody, so a viewer with
  # no groups and no ACL grant is somebody the policy refuses.
  def permit_nothing
    @controller.define_singleton_method(:current_user_group_names) { Set.new }
    @controller.define_singleton_method(:current_user_submission_action_permission_keys) { Set.new }
  end

  def permit_everything
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end

  test 'a viewer who may edit the submission gets its edit history' do
    permit_everything
    Current.set(user: session[:user]) { @record.update!(work_location: 'Camarillo') }

    get :edits, params: { type: @record.class.name, id: @record.id }

    assert_response :success
    assert_match 'Work location', response.body
    assert_match 'Camarillo', response.body
  end

  test 'a viewer who may not edit the submission is refused its edit history' do
    get :edits, params: { type: @record.class.name, id: @record.id }

    assert_response :forbidden
  end

  test 'an unedited submission renders an empty trail rather than an error' do
    permit_everything

    get :edits, params: { type: @record.class.name, id: @record.id }

    assert_response :success
    assert_match 'No edits have been made', response.body
  end

  test 'a model that keeps no edit trail cannot be rendered' do
    permit_everything

    get :edits, params: { type: 'Forms::Template', id: 1 }

    assert_response :not_found
  end

  test 'an unknown type cannot be rendered' do
    permit_everything

    get :edits, params: { type: 'Object', id: 1 }

    assert_response :not_found
  end

  test 'a missing submission is a 404, not a 403' do
    permit_everything

    get :edits, params: { type: @record.class.name, id: 0 }

    assert_response :not_found
  end

  test 'status history is readable without the edit right' do
    get :status, params: { type: @record.class.name, id: @record.id }

    assert_response :success
  end
end
