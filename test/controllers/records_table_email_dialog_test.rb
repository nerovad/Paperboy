# frozen_string_literal: true

require 'test_helper'

# The Records grid's Email button and dialog, which only the table's editors
# are shown (see RecordsEmailDialog for the endpoints behind it).
class RecordsTableEmailDialogTest < ActionController::TestCase
  tests RecordsTableController

  test 'editors get an Email button between Highlights and Export, and its dialog' do
    sign_in(groups: %w[system_admins])
    FleetVehicle.create!(vehicle_number: 'V1', agency: 'GSA')
    RecordsEmailRule.create!(table_slug: 'fleet', column_name: 'updated_at', operator: 'older_than_days',
                             value: '365', label: 'Out of compliance', message: 'Please update', split_column: 'agency',
                             employee_id: '1', frequency: 'weekly', day_of_week: 1, time_of_day: '07:00')
    RecordsEmailContact.new(table_slug: 'fleet', column_name: 'agency', match_value: 'GSA',
                            email: 'gsa@ventura.org').save!(validate: false)
    RecordsEmailDelivery.create!(table_slug: 'fleet', subject: 'Fleet Vehicles (1 row)', recipients: 'a@ventura.org',
                                 row_count: 1)

    get :show, params: { slug: 'fleet', email: 'open' }

    assert_response :success
    assert_equal %w[Highlights Email Export], css_select('.records-bar__actions button').map(&:text).first(3)
    assert_select '[data-records-email-target="backdrop"]:not([hidden])' do
      assert_select '.records-email__item strong', text: 'Out of compliance'
      assert_select '.records-email__item small', text: "To: Each Agency's contacts"
      assert_select '.records-email__contact', text: /gsa@ventura.org/
      assert_select 'select[name="rule[split_column]"] option[value="agency"]'
    end
  end

  test 'viewers without the edit grant get no Email button or dialog' do
    sign_in(groups: [], record_view: %w[fleet])

    get :show, params: { slug: 'fleet' }

    assert_response :success
    assert_select '.records-bar__actions button', text: 'Email', count: 0
    assert_select '[data-records-email-target="backdrop"]', count: 0
  end

  private

  def sign_in(groups:, record_view: [])
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    group_names = groups.to_set
    view_keys = record_view.to_set
    @controller.define_singleton_method(:current_user_group_names) { group_names }
    @controller.define_singleton_method(:current_user_record_view_permission_keys) { view_keys }
    @controller.define_singleton_method(:current_user_record_edit_permission_keys) { Set.new }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
  end
end
