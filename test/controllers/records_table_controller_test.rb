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

  # The access grant is the only route to a form-backed table, which declares
  # neither a group permission nor a dropdown key. Without it an edit grant on
  # such a table is unreachable no matter what an admin ticks in the ACL.
  test 'the access grant opens a table the user has no other route to' do
    sign_in(groups: [], record_view: %w[pcard], record_edit: %w[pcard])

    patch :bulk_update, params: { slug: 'pcard' }

    assert_response :success
  end

  test 'the access grant alone still does not grant editing' do
    sign_in(groups: [], record_view: %w[pcard], record_edit: [])

    patch :bulk_update, params: { slug: 'pcard' }

    assert_response :forbidden
  end

  test 'the html grid renders one page and keeps the full set for export' do
    sign_in(groups: [], record_view: %w[fleet], record_edit: [])
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
    rows = Array.new(Pfa::Grid::Table::PAGE_ROWS + 1) { |number| Struct.new(:id).new(number + 1) }
    highlights = Object.new
    def highlights.rule_for(_) = nil
    def highlights.any? = false
    view = Struct.new(:columns, :rows, :filter_options, :default_sort, :highlights, :highlight_counts)
                 .new([], rows, {}, nil, highlights, nil)
    RecordsView.stub(:new, view) do
      get :show, params: { slug: 'fleet' }
    end

    assert_select 'tbody tr', count: Pfa::Grid::Table::PAGE_ROWS
    assert_select '.pagination-wrapper .pagy.series-nav'
    assert_match(/Showing 1–#{Pfa::Grid::Table::PAGE_ROWS} of #{rows.size} rows/, response.body)
  end

  test 'downloads the grid view as a CSV' do
    sign_in(groups: [], record_view: %w[fleet], record_edit: [])
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }

    get :show, params: { slug: 'fleet', format: :csv }

    assert_response :success
    assert_equal 'text/csv', response.media_type
    assert_match(/attachment; filename="fleet-\d{4}-\d{2}-\d{2}\.csv"/, response.headers['Content-Disposition'])
    assert_equal TableColumns.resolve('records:fleet', TableColumns.default_layout('records:fleet')).map(&:label),
                 CSV.parse(response.body).first
  end

  test 'the CSV download is gated like the grid' do
    sign_in(groups: [], record_edit: [])
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }

    get :show, params: { slug: 'fleet', format: :csv }

    assert_redirected_to root_path
  end

  # The 300A Summary totals the 300 Log, so that table alone links to it.
  test 'the OSHA 300 Log offers the 300A Summary ahead of Changes' do
    sign_in(groups: %w[system_admins], record_edit: [])

    get :show, params: { slug: 'osha-300-log' }

    assert_response :success
    assert_select '.records-bar__actions a:first-child', text: 'OSHA 300A Summary'
    assert_select '.records-bar__actions a:first-child + a', text: 'Changes'
  end

  test 'other tables do not offer the 300A Summary' do
    sign_in(groups: %w[system_admins], record_edit: [])

    get :show, params: { slug: 'fleet' }

    assert_response :success
    assert_select '.records-bar__actions a', text: 'OSHA 300A Summary', count: 0
  end

  test 'an unknown table is not found' do
    sign_in(groups: %w[system_admins], record_edit: [])

    patch :bulk_update, params: { slug: 'no-such-table' }

    assert_response :not_found
  end

  private

  def sign_in(groups:, record_edit:, record_view: [])
    session[:user] = {
      'employee_id' => 1,
      'email' => 'employee@example.com',
      'first_name' => 'Test',
      'last_name' => 'User'
    }
    stub_permissions(groups, record_view, record_edit)
  end

  # All three readers are helper_methods, so stubbing them on the controller
  # also covers the ApplicationHelper calls made through `helpers`.
  def stub_permissions(groups, record_view, record_edit)
    group_names = groups.to_set
    view_keys = record_view.to_set
    edit_keys = record_edit.to_set
    @controller.define_singleton_method(:current_user_group_names) { group_names }
    @controller.define_singleton_method(:current_user_record_view_permission_keys) { view_keys }
    @controller.define_singleton_method(:current_user_record_edit_permission_keys) { edit_keys }
  end
end
