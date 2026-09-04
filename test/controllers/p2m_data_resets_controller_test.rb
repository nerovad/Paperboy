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
    assert_select 'button.btn.deny', text: 'Reset Data', count: 1
    assert_select '.p2m-maildat-table', count: 1
    assert_select '.p2m-maildat-row', text: /P2M_STAGING/, count: 1
  end

  test 'shows nested printers, queues, OMS numbers, and files' do
    sign_in
    results = [
      reset_result('P2M_PRINTERS', ['Printer One/Queue A/printed.pdf']),
      reset_result('P2M_STAGING', ['51780767-tray-labels.pdf', 'Mail.dat_51780767.zip']),
      reset_result('p2m_oms_backfill_report.json', ['p2m_oms_backfill_report.json'])
    ]
    reset = Object.new
    reset.define_singleton_method(:preview) { results }

    P2m::DataReset.stub(:new, reset) { get :show }

    assert_response :success
    assert_select '.p2m-production-printer-row', text: /Printer One/, count: 1
    assert_select '.p2m-production-queue-row', text: /Queue A/, count: 1
    assert_select '.p2m-production-queue-detail[hidden] li', text: 'printed.pdf', count: 1
    assert_select '.p2m-production-oms-row', text: /51780767/, count: 1
    assert_select '.p2m-production-oms-detail[hidden] li', count: 2
    assert_select '.p2m-maildat-detail[hidden] li', text: 'p2m_oms_backfill_report.json', count: 1
  end

  test 'resets one target as JSON for progressive row removal' do
    sign_in
    results = [{
      'target' => 'P2M_STAGING', 'action' => 'Files removed',
      'items' => ['output.pdf'], 'count' => 1, 'error' => false
    }]
    reset = Object.new
    reset.define_singleton_method(:reset_target) { |_target| results }

    P2m::DataReset.stub(:new, reset) do
      post :create, params: { target: 'P2M_STAGING' }, format: :json
    end

    assert_response :success
    assert_equal 'Reset target removed.', response.parsed_body.fetch('message')
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

  def reset_result(target, items)
    { 'target' => target, 'action' => 'Files found', 'items' => items,
      'count' => items.size, 'error' => false }
  end

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end
end
