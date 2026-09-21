# frozen_string_literal: true

require 'test_helper'

# A scheduled export keeps emailing a table after the page is closed, so the
# gate has to hold at creation and a schedule has to stay its owner's alone.
class RecordExportSchedulesControllerTest < ActionController::TestCase
  tests RecordExportSchedulesController

  SCHEDULE = { frequency: 'weekly', day_of_week: '1', time_of_day: '07:00' }.freeze

  test 'someone who cannot open the table cannot schedule its export' do
    sign_in(groups: [])

    assert_no_difference -> { ScheduledRecordExport.count } do
      post :create, params: { slug: 'fleet', schedule: SCHEDULE }
    end
    assert_redirected_to root_path
  end

  test 'schedules the view the grid was showing' do
    sign_in(groups: [], record_view: %w[fleet])

    post :create, params: { slug: 'fleet', schedule: SCHEDULE,
                            view: { search: 'ford', filter_make: 'Ford', page: '2' } }

    export = ScheduledRecordExport.last
    assert_equal '1', export.employee_id
    assert_equal 'fleet', export.table_slug
    assert_equal({ 'search' => 'ford', 'filter_make' => 'Ford' }, export.view_params)
    assert_equal TableColumns.default_layout('records:fleet'), export.layout
    assert_redirected_to records_table_path('fleet', search: 'ford', filter_make: 'Ford')
  end

  test "cannot pause or delete someone else's schedule" do
    sign_in(groups: %w[system_admins])
    theirs = ScheduledRecordExport.create!(employee_id: '2002', table_slug: 'fleet', frequency: 'daily',
                                           time_of_day: '07:00')

    patch :toggle, params: { slug: 'fleet', id: theirs.id }
    assert_predicate theirs.reload, :enabled?

    assert_no_difference -> { ScheduledRecordExport.count } do
      delete :destroy, params: { slug: 'fleet', id: theirs.id }
    end
  end

  test 'resuming a paused schedule starts from now' do
    sign_in(groups: %w[system_admins])
    mine = ScheduledRecordExport.create!(employee_id: '1', table_slug: 'fleet', frequency: 'daily',
                                         time_of_day: '07:00', enabled: false)
    mine.update_column(:next_run_at, 1.month.ago)

    patch :toggle, params: { slug: 'fleet', id: mine.id }

    assert_predicate mine.reload, :enabled?
    assert_operator mine.next_run_at, :>, Time.current
  end

  private

  def sign_in(groups:, record_view: [])
    session[:user] = {
      'employee_id' => 1,
      'email' => 'employee@example.com',
      'first_name' => 'Test',
      'last_name' => 'User'
    }
    group_names = groups.to_set
    view_keys = record_view.to_set
    @controller.define_singleton_method(:current_user_group_names) { group_names }
    @controller.define_singleton_method(:current_user_record_view_permission_keys) { view_keys }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
  end
end
