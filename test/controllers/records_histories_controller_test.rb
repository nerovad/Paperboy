# frozen_string_literal: true

require 'test_helper'

# A table's history names who changed what, so it follows the edit grant: being
# able to open a table is not enough to read its change log.
class RecordsHistoriesControllerTest < ActionController::TestCase
  tests RecordsHistoriesController

  setup do
    @card = PcardInventory.create!(first_name: 'Ada', last_name: 'Lovelace', monthly_limit: 100)
    @card.update!(monthly_limit: 250)
  end

  test 'a viewer without the edit grant cannot open the change log' do
    sign_in(groups: %w[pcard_admin], record_edit: [])

    get :index, params: { slug: 'pcard' }

    assert_redirected_to root_path
  end

  test "a viewer without the edit grant cannot fetch a row's history" do
    sign_in(groups: %w[pcard_admin], record_edit: [])

    get :row, params: { slug: 'pcard', id: @card.id }

    assert_response :forbidden
  end

  test "an editor gets a row's history fragment" do
    sign_in(groups: %w[pcard_admin], record_edit: %w[pcard])

    get :row, params: { slug: 'pcard', id: @card.id }

    assert_response :success
    assert_includes response.body, 'Monthly Limit'
    assert_includes response.body, 'Added'
  end

  test 'a row from another table is not found' do
    sign_in(groups: %w[system_admins], record_edit: [])

    get :row, params: { slug: 'pcard', id: 0 }

    assert_response :not_found
  end

  test 'an editor downloads the change log as CSV' do
    sign_in(groups: %w[system_admins], record_edit: [])

    get :index, params: { slug: 'pcard', change: 'update', format: :csv }

    assert_response :success
    rows = CSV.parse(response.body)
    assert_equal 'Changed At', rows.first.first
    assert_equal([['Edited', 'Ada Lovelace', 'Monthly Limit']], rows.drop(1).map { |row| row.values_at(3, 4, 6) })
  end

  private

  def sign_in(groups:, record_edit:)
    session[:user] = {
      'employee_id' => 1,
      'email' => 'employee@example.com',
      'first_name' => 'Test',
      'last_name' => 'User'
    }
    group_names = groups.to_set
    edit_keys = record_edit.to_set
    @controller.define_singleton_method(:current_user_group_names) { group_names }
    @controller.define_singleton_method(:current_user_record_view_permission_keys) { Set.new }
    @controller.define_singleton_method(:current_user_record_edit_permission_keys) { edit_keys }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
  end
end
