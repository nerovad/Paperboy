# frozen_string_literal: true

require 'test_helper'

# The inline-edit endpoint is the one place a Records grid writes to the
# database, so the edit grant has to hold there and not only in the view that
# renders (or hides) the Edit button.
class RecordsTableControllerTest < ActionController::TestCase
  tests RecordsTableController

  test 'being able to view a table does not grant editing it' do
    sign_in(groups: %w[pcard_admin], record_edit: [])

    patch :bulk_update, params: { slug: 'pcard' }

    assert_response :forbidden
  end

  test 'the edit grant opens the batch endpoint' do
    sign_in(groups: %w[pcard_admin], record_edit: %w[pcard])

    patch :bulk_update, params: { slug: 'pcard' }

    assert_response :success
  end

  test 'system admins bypass the edit grant' do
    sign_in(groups: %w[system_admins], record_edit: [])

    patch :bulk_update, params: { slug: 'pcard' }

    assert_response :success
  end

  test 'an edit grant on a table the user cannot open is still forbidden' do
    sign_in(groups: [], record_edit: %w[pcard])

    patch :bulk_update, params: { slug: 'pcard' }

    assert_response :forbidden
  end

  test 'an unknown table is not found' do
    sign_in(groups: %w[system_admins], record_edit: [])

    patch :bulk_update, params: { slug: 'no-such-table' }

    assert_response :not_found
  end

  private

  def sign_in(groups:, record_edit:)
    session[:user] = {
      'employee_id' => 1,
      'email' => 'employee@example.com',
      'first_name' => 'Test',
      'last_name' => 'User'
    }
    stub_permissions(groups, record_edit)
  end

  # Both readers are helper_methods, so stubbing them on the controller also
  # covers the ApplicationHelper calls made through `helpers`.
  def stub_permissions(groups, record_edit)
    group_names = groups.to_set
    edit_keys = record_edit.to_set
    @controller.define_singleton_method(:current_user_group_names) { group_names }
    @controller.define_singleton_method(:current_user_record_edit_permission_keys) { edit_keys }
  end
end
