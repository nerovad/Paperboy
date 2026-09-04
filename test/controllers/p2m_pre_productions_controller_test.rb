# frozen_string_literal: true

require 'test_helper'

class P2mPreProductionsControllerTest < ActionController::TestCase # rubocop:disable Metrics/ClassLength
  tests P2m::PreProductionsController

  test 'shows the shared Mail.dat grid with pre-production batch action' do
    sign_in
    report = {
      'source_root' => Pathname.new(ENV.fetch('P2M_DATARUNNER_ROOT')).parent.to_s,
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
    catalog = { 'Printer One' => ['Queue A', 'Queue B'] }
    printer_catalog = Object.new
    printer_catalog.define_singleton_method(:call) { catalog }

    P2m::PrinterCatalog.stub(:new, printer_catalog) do
      P2m::PrintAndInsertingDone.stub(:scan, report) do
        get :show, params: {
          pre_production: { start_date: '2026-08-01', end_date: '2026-08-31' }
        }
      end
    end

    assert_response :success
    assert_select '.p2m-maildat-table tr[data-oms-number="51780767"]', count: 1
    assert_select 'button[data-printer-selection-mode-value="batch"]',
                  text: 'Send All to Printer', count: 1 do |buttons|
      assert_equal catalog.to_json, buttons.first['data-printer-selection-catalog-value']
    end
    assert_select 'button[data-printer-selection-mode-value="batch"]',
                  text: 'Remove All from Printer', count: 1 do |buttons|
      assert_equal 'remove', buttons.first['data-printer-selection-operation-value']
      assert_equal catalog.to_json, buttons.first['data-printer-selection-catalog-value']
    end
    assert_select 'button', text: 'Move All to Staging', count: 0
  end

  test 'shows pre-production row actions in expanded details' do
    sign_in
    associated_files = Object.new
    associated_files.define_singleton_method(:call) { |**| ['51780767.zip', 'tray-labels.pdf'] }
    catalog = { 'Printer One' => ['Queue A', 'Queue B'] }
    printer_catalog = Object.new
    printer_catalog.define_singleton_method(:call) { catalog }

    P2m::PrinterCatalog.stub(:new, printer_catalog) do
      P2m::OmsAssociatedFiles.stub(:new, associated_files) do
        get :details, params: { directory: '2026/51780767', oms_number: '51780767' }
      end
    end

    assert_response :success
    assert_select 'button', text: 'Send to Printer', count: 1
    assert_select 'button', text: 'Remove from Printer', count: 1
    assert_select 'button[data-printer-selection-catalog-value]', count: 1 do |buttons|
      assert_equal catalog.to_json, buttons.first['data-printer-selection-catalog-value']
    end
    assert_select 'a[data-action="pdf-preview#open"]', text: 'tray-labels.pdf', count: 1
    assert_select '[data-pdf-preview-target="backdrop"]', count: 1
    assert_select '.p2m-associated-files-table thead th', count: 4
    assert_select '.p2m-associated-files-table tbody tr:first-child td', count: 4
    assert_select 'input[type="checkbox"][name="selected_files[]"]', count: 2
    assert_select 'button', text: 'Cancel', count: 1
    assert_select 'button', text: 'Move to Staging', count: 0
  end

  test 'copies selected files to the confirmed printer queue' do
    sign_in
    catalog = { 'Printer One' => ['Queue A'] }
    printer_catalog = Object.new
    printer_catalog.define_singleton_method(:call) { catalog }
    printer_queue = Minitest::Mock.new
    copy_parameters = {
      directory: '2026/51780767', oms_number: '51780767', printer: 'Printer One',
      queue: 'Queue A', filenames: ['one.pdf', 'two.csv']
    }
    printer_queue.expect :copy, 2, [copy_parameters]

    P2m::PrinterCatalog.stub(:new, printer_catalog) do
      P2m::PrinterQueue.stub(:new, printer_queue) do
        post :send_to_printer, params: {
          directory: '2026/51780767', oms_number: '51780767', printer: 'Printer One',
          queue: 'Queue A', selected_files: ['one.pdf', 'two.csv']
        }
      end
    end

    assert_response :success
    assert_kind_of Numeric, response.parsed_body.fetch('elapsed_seconds')
    assert_match '2 files copied to Printer One/Queue A', response.parsed_body.fetch('message')
    printer_queue.verify
  end

  test 'rejects a printer and queue outside the catalog' do
    sign_in
    printer_catalog = Object.new
    printer_catalog.define_singleton_method(:call) { { 'Printer One' => ['Queue A'] } }

    P2m::PrinterCatalog.stub(:new, printer_catalog) do
      post :send_to_printer, params: {
        directory: 'job', oms_number: '51780767', printer: 'Printer One', queue: 'Other'
      }
    end

    assert_response :unprocessable_content
    assert_equal 'invalid printer or queue', response.parsed_body.fetch('message')
  end

  test 'removes selected files from the confirmed printer queue' do
    sign_in
    printer_catalog = Object.new
    printer_catalog.define_singleton_method(:call) { { 'Printer One' => ['Queue A'] } }
    printer_queue = Minitest::Mock.new
    parameters = {
      directory: 'job', oms_number: '51780767', printer: 'Printer One',
      queue: 'Queue A', filenames: ['one.pdf']
    }
    printer_queue.expect :remove, 1, [parameters]

    P2m::PrinterCatalog.stub(:new, printer_catalog) do
      P2m::PrinterQueue.stub(:new, printer_queue) do
        delete :remove_from_printer, params: parameters.merge(selected_files: ['one.pdf'])
      end
    end

    assert_response :success
    assert_match '1 file removed from Printer One/Queue A', response.parsed_body.fetch('message')
    printer_queue.verify
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end
end # rubocop:enable Metrics/ClassLength
