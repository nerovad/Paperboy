# frozen_string_literal: true

require 'test_helper'

class P2mPreProductionsControllerTest < ActionController::TestCase
  tests P2m::PreProductionsController

  test 'shows the shared Mail.dat grid with pre-production batch action' do
    sign_in
    report = {
      'source_root' => '/mnt/o/Outputs',
      'start_date' => '2026-08-01',
      'end_date' => '2026-08-31',
      'found_count' => 1,
      'search_seconds' => 0.125,
      'files' => [{
        'oms_number' => '51780767',
        'directory' => '2026/51780767',
        'modified_at' => '2026-08-21 10:30:00',
        'associated_file_count' => 3
      }]
    }

    P2m::PrintAndInsertingDone.stub(:scan, report) do
      get :show, params: {
        pre_production: { start_date: '2026-08-01', end_date: '2026-08-31' }
      }
    end

    assert_response :success
    assert_select '.p2m-maildat-table tr[data-oms-number="51780767"]', count: 1
    assert_select 'button', text: 'Send All to Printer', count: 1
    assert_select 'button', text: 'Move All to Staging', count: 0
  end

  test 'shows pre-production row actions in expanded details' do
    sign_in
    associated_files = Object.new
    associated_files.define_singleton_method(:call) { |**| ['51780767.zip', 'tray-labels.pdf'] }

    P2m::OmsAssociatedFiles.stub(:new, associated_files) do
      get :details, params: { directory: '2026/51780767', oms_number: '51780767' }
    end

    assert_response :success
    assert_select 'button', text: 'Send to Printer', count: 1
    assert_select 'button', text: 'Cancel', count: 1
    assert_select 'button', text: 'Move to Staging', count: 0
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end
end
