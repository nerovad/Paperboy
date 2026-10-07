# frozen_string_literal: true

require 'test_helper'

module P2mFeatureGrant
  def grant_p2m(*feature_keys)
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    keys = feature_keys
    @controller.define_singleton_method(:current_user_group_names) { Set['staff'] }
    @controller.define_singleton_method(:current_user_application_permission_keys) { ['p2m'] }
    @controller.define_singleton_method(:current_user_feature_permission_keys) { keys }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { [] }
  end

  def job_params
    { directory: '2026/51780767', oms_number: '51780767', printer: 'Printer One', queue: 'Queue A' }
  end

  def mail_report
    {
      'source_root' => '/mail', 'start_date' => '2026-08-01', 'end_date' => '2026-08-31',
      'found_count' => 1, 'search_seconds' => 0.1,
      'files' => [{
        'oms_number' => '51780767', 'directory' => '2026/51780767',
        'modified_at' => '2026-08-21 10:30:00', 'associated_file_count' => 3
      }]
    }
  end

  def refuse(service, verb, action)
    service.stub(:new, ->(*) { raise "#{service} ran" }) do
      send(verb, action, params: job_params)
    end
    assert_response :forbidden
    assert_equal 'Access denied.', response.parsed_body.fetch('message')
  end
end

class P2mPreProductionChangeJobTest < ActionController::TestCase
  tests P2m::PreProductionsController
  include P2mFeatureGrant

  test 'search stays available and hides printer and destroy actions' do
    grant_p2m('p2m:stage_data')
    catalog = Object.new
    catalog.define_singleton_method(:call) { { 'Printer One' => ['Queue A'] } }

    P2m::PrinterCatalog.stub(:new, catalog) do
      P2m::PrintAndInsertingDone.stub(:scan, mail_report) do
        get :show, params: { pre_production: { start_date: '2026-08-01', end_date: '2026-08-31' } }
      end
    end

    assert_response :success
    assert_select '.p2m-maildat-table tr[data-oms-number="51780767"]', count: 1
    assert_select 'button', text: 'Send All to Printer', count: 0
    assert_select 'button', text: 'Remove All from Printer', count: 0
  end

  test 'job details keep file links and hide send, remove, and destroy' do
    grant_p2m('p2m:stage_data')
    files = Object.new
    files.define_singleton_method(:call) { |**| ['51780767.zip', 'tray-labels.pdf'] }
    catalog = Object.new
    catalog.define_singleton_method(:call) { { 'Printer One' => ['Queue A'] } }

    P2m::PrinterCatalog.stub(:new, catalog) do
      P2m::OmsAssociatedFiles.stub(:new, files) do
        get :details, params: job_params
      end
    end

    assert_response :success
    assert_select 'a', text: 'tray-labels.pdf', count: 1
    assert_select 'button', text: 'Cancel', count: 1
    assert_select 'button', text: 'Send to Printer', count: 0
    assert_select 'button', text: 'Remove from Printer', count: 0
    assert_select 'button', text: 'Destroy', count: 0
  end

  test 'send, remove, and destroy are refused without the change grant' do
    grant_p2m('p2m:stage_data')
    refuse(P2m::PrinterQueue, :post, :send_to_printer)
    refuse(P2m::PrinterQueue, :delete, :remove_from_printer)
    refuse(P2m::OmsDestroyer, :delete, :destroy_oms)
  end

  test 'the change grant alone does not open pre-production' do
    grant_p2m('p2m:change_job')
    post :send_to_printer, params: job_params
    assert_redirected_to p2m_root_path
  end

  test 'the change grant can send a job to the printer' do
    grant_p2m('p2m:stage_data', 'p2m:change_job')
    catalog = Object.new
    catalog.define_singleton_method(:call) { { 'Printer One' => ['Queue A'] } }
    queue = Object.new
    queue.define_singleton_method(:copy) { |**| 2 }

    P2m::PrinterCatalog.stub(:new, catalog) do
      P2m::PrinterQueue.stub(:new, queue) do
        post :send_to_printer, params: job_params.merge(selected_files: ['one.pdf'])
      end
    end

    assert_response :success
    assert_match '2 files copied to Printer One/Queue A', response.parsed_body.fetch('message')
  end
end

class P2mStageDataChangeJobTest < ActionController::TestCase
  tests P2m::StageDataController
  include P2mFeatureGrant

  test 'search stays available and hides shipping and staging actions' do
    grant_p2m('p2m:stage_data')

    P2m::PrintAndInsertingDone.stub(:scan, mail_report) do
      post :create, params: { stage_data: { start_date: '2026-08-01', end_date: '2026-08-31' } }
    end

    assert_response :success
    assert_select '.p2m-maildat-table tr[data-oms-number="51780767"]', count: 1
    assert_select 'button', text: 'Send All to Shipping Station', count: 0
    assert_select 'button', text: 'Move All to Staging', count: 0
  end

  test 'job details keep tray labels, preview, and USPS' do
    grant_p2m('p2m:stage_data')
    files = Object.new
    files.define_singleton_method(:call) { |**| ['Mail.dat_51780767.zip', 'tray-labels.pdf'] }

    P2m::OmsAssociatedFiles.stub(:new, files) do
      get :details, params: job_params
    end

    assert_response :success
    assert_select 'a', text: 'Print Tray Labels', count: 1
    assert_select 'a', text: 'Upload to USPS', count: 1
    assert_select 'a', text: 'tray-labels.pdf', count: 1
    assert_select 'button', text: 'Cancel', count: 1
    assert_select 'button', text: 'Send to Shipping Station', count: 0
    assert_select 'button', text: 'Remove from Shipping Station', count: 0
    assert_select 'button', text: 'Move to Staging', count: 0
    assert_select 'button', text: 'Remove from Staging', count: 0
  end

  test 'tray labels stay on the look grant' do
    grant_p2m('p2m:stage_data')
    tray = Tempfile.new(['tray', '.pdf'])
    tray.write('%PDF')
    tray.close
    path = Pathname.new(tray.path)
    labels = Object.new
    labels.define_singleton_method(:tray_labels) { |**| path }

    P2m::OmsAssociatedFiles.stub(:new, labels) do
      get :print_tray_labels, params: job_params
    end

    assert_response :success
    assert_equal '%PDF', response.body
  end

  test 'single job shipping and staging ask before they run' do
    grant_p2m('p2m:stage_data', 'p2m:change_job')
    files = Object.new
    files.define_singleton_method(:call) { |**| ['Mail.dat_51780767.zip', 'tray-labels.pdf'] }

    P2m::OmsAssociatedFiles.stub(:new, files) do
      get :details, params: job_params
    end

    assert_response :success
    assert_job_confirmation 'Send to Shipping Station', 'reassign', P2m::Paths::SHIPPING_STATION,
                            'Copy one Mail.dat file for OMS 51780767',
                            'Associated files will not be copied.'
    assert_job_confirmation 'Move to Staging', 'approve', P2m::Paths::STAGING,
                            'Validate and copy 2 associated files for OMS 51780767',
                            'A successful move removes this OMS from the grid.'
  end

  test 'shipping and staging are refused without the change grant' do
    grant_p2m('p2m:stage_data')
    refuse(P2m::OmsStaging, :post, :move_to_staging)
    refuse(P2m::OmsStaging, :delete, :remove_from_staging)
    refuse(P2m::OmsShippingStation, :post, :move_to_shipping_station)
    refuse(P2m::OmsShippingStation, :delete, :remove_from_shipping_station)
  end

  test 'the change grant can move a job to staging' do
    grant_p2m('p2m:stage_data', 'p2m:change_job')
    ledger = Object.new
    ledger.define_singleton_method(:ensure_stageable!) { |**| nil }
    ledger.define_singleton_method(:validate!) { |**| { valid: true } }
    ledger.define_singleton_method(:staged!) { |**| nil }
    files = Object.new
    files.define_singleton_method(:call) { |**| [] }
    staging = Object.new
    staging.define_singleton_method(:stage) { |**| 4 }

    P2m::OmsUploadLedger.stub(:new, ->(*_args, **_kwargs) { ledger }) do
      P2m::OmsAssociatedFiles.stub(:new, files) do
        P2m::OmsStaging.stub(:new, staging) do
          post :move_to_staging, params: job_params
        end
      end
    end

    assert_response :success
    assert_match '4 files copied', response.parsed_body.fetch('message')
  end

  private

  def assert_job_confirmation(label, variant, destination, *fragments)
    assert_select 'button', text: label, count: 1 do |buttons|
      message = buttons.first['data-confirm-message']
      assert_includes message, destination
      fragments.each { |fragment| assert_includes message, fragment }
      assert_equal 'Continue', buttons.first['data-confirm-label']
      assert_equal variant, buttons.first['data-confirm-variant']
    end
  end
end

class P2mProductionChangeJobTest < ActionController::TestCase
  tests P2m::ProductionsController
  include P2mFeatureGrant

  test 'production preview stays on the look grant' do
    grant_p2m('p2m:stage_data')
    preview = Tempfile.new(['preview', '.pdf'])
    preview.write('%PDF')
    preview.close
    path = Pathname.new(preview.path)
    files = Object.new
    files.define_singleton_method(:preview) { |**| path }

    P2m::ProductionFiles.stub(:new, files) do
      get :preview, params: { printer: 'Printer One', queue: 'Queue A', filename: 'output.pdf' }
    end

    assert_response :success
    assert_equal '%PDF', response.body
  end
end
