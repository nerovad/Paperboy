# frozen_string_literal: true

require 'test_helper'

class P2mDataResetsControllerTest < ActionController::TestCase
  tests P2m::DataResetsController

  test 'shows the confirmed reset action' do
    sign_in
    results = [{
      'target' => 'P2M_STAGING', 'action' => 'Files found',
      'items' => ['output.pdf'], 'count' => 1, 'error' => false
    }]
    reset = Object.new
    reset.define_singleton_method(:preview) { results }

    P2m::DataReset.stub(:new, reset) { get :show }

    assert_response :success
    assert_select 'form[data-turbo-confirm][action=?]', p2m_data_reset_path, count: 1
    assert_select 'button.btn.deny', text: 'Reset Data', count: 1
    assert_select '.p2m-maildat-table', count: 1
    assert_select '.p2m-maildat-row', text: /P2M_STAGING/, count: 1
  end

  test 'runs reset and shows collapsible results' do
    sign_in
    results = [{
      'target' => 'P2M_STAGING', 'action' => 'Files removed',
      'items' => ['output.pdf'], 'count' => 1, 'error' => false
    }, {
      'target' => 'GSABSS.dbo.companions', 'action' => 'Rows truncated',
      'items' => ['2 rows'], 'count' => 2, 'error' => false
    }, {
      'target' => 'GSABSS.dbo.p2m_oms_uploads', 'action' => 'Rows deleted',
      'items' => ['3 rows'], 'count' => 3, 'error' => false
    }]
    reset = Object.new
    reset.define_singleton_method(:call) { results }
    reset.define_singleton_method(:preview) do
      [{
        'target' => 'P2M_STAGING', 'action' => 'Files found',
        'items' => [], 'count' => 0, 'error' => false
      }]
    end

    P2m::DataReset.stub(:new, reset) { post :create }

    assert_response :success
    assert_select '.p2m-maildat-row', text: /P2M_STAGING/, count: 1
    assert_select '.p2m-maildat-row td', text: '0', count: 1
    assert_select '.p2m-maildat-row', text: /GSABSS database tables/, count: 0
    assert_select '.p2m-row-trigger[aria-expanded="false"]', count: 1
    assert_select '.p2m-maildat-detail[hidden] li', text: 'output.pdf', count: 0
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end
end
