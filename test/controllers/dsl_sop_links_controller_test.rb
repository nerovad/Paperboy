# frozen_string_literal: true

require 'test_helper'

class DslSopLinksControllerTest < ActionController::TestCase
  tests DataRunner::DslsController

  test 'DSL group shows configured download instructions' do
    sign_in

    get :index, params: { group: 'print_2_mail_billing_data' }

    assert_response :success
    assert_select '.dsl-sop-scope button.btn.info[data-action=?]', 'sop-modal#open',
                  text: 'How to Download'
    assert_select '.dsl-sop-scope .pb-modal[role=?][aria-modal=?]', 'dialog', 'true'
  end

  test 'DSL with an SOP renders a download instructions modal' do
    sign_in

    get :show, params: { name: 'usps' }

    assert_response :success
    assert_select 'button.btn.info[data-action=?]', 'sop-modal#open', text: 'How to Download'
    assert_select '.pb-modal[role=?][aria-modal=?]', 'dialog', 'true'
    assert_select '.dsl-sop ol li', count: 5
    assert_select '.pb-modal__actions a.btn.pdf[href=?]',
                  'https://gateway.usps.com/eAdmin/view/signin', text: 'Open'
    assert_select '.pb-modal__actions button.btn.pdf[data-action=?][data-url=?]',
                  'sop-modal#openReference', reference_data_runner_dsl_path('usps'), text: 'View File'
    assert_select '.pb-modal__actions button.btn', text: 'Close'
  end

  test 'DSL without an SOP does not render the modal trigger' do
    sign_in

    get :show, params: { name: 'employees' }

    assert_response :success
    assert_select '[data-action=?]', 'sop-modal#open', count: 0
    assert_select '.pb-modal', count: 0
  end

  test 'SOP with a reference folder links to its directory listing' do
    sign_in

    get :show, params: { name: 'oversized' }

    assert_response :success
    assert_select '.pb-modal__actions button.btn.pdf[data-action=?][data-url=?]',
                  'sop-modal#openReference', reference_data_runner_dsl_path('oversized'), text: 'View File'
    assert_select '.pb-modal.pb-modal--xl[role=?][aria-modal=?]', 'dialog', 'true'
    assert_select '.pb-modal.pb-modal--xl h3', text: 'Scanner Export Folder'
  end

  test 'SOP with a reference file uses its configured dialog title' do
    sign_in

    get :show, params: { name: 'document_automation' }

    assert_response :success
    assert_select '.pb-modal.pb-modal--xl h3', text: 'Document Automation File'
  end

  test 'ONeil SOP opens its source location details' do
    sign_in

    get :show, params: { name: 'oneil' }

    assert_response :success
    assert_select '.pb-modal__actions button.btn.pdf[data-action=?][data-url=?]',
                  'sop-modal#openReference', reference_data_runner_dsl_path('oneil'), text: 'View File'
    assert_select '.pb-modal.pb-modal--xl h3', text: 'ONeil Record Storage'
  end

  test 'SOP may render only an external URL action' do
    sign_in

    get :show, params: { name: 'vcprint' }

    assert_response :success
    assert_select '.pb-modal__actions a.btn.pdf', text: 'Open', count: 1
    assert_select '.pb-modal__actions button.btn.pdf', text: 'View File', count: 0
  end

  test 'HTTP download SOP opens its source site and downloaded file' do
    sign_in

    get :show, params: { name: 'agencies' }

    assert_response :success
    assert_select '.pb-modal__actions a.btn.pdf[href=?][target=?]',
                  'http://acweb/cutoff', '_blank', text: 'Open'
    assert_select '.pb-modal__actions button.btn.pdf[data-action=?][data-url=?]',
                  'sop-modal#openReference', reference_data_runner_dsl_path('agencies'), text: 'View File'
    assert_select '.pb-modal__actions a.btn.pdf[href=?]',
                  data_runner_root_path(group: 'chart_of_accounts', anchor: 'refresh-group'), text: 'View Group'
    assert_select '.pb-modal.pb-modal--xl h3', text: 'Downloaded Agencies File'
  end

  test 'shared Chart of Accounts SOP displays each DSL downloaded file' do
    sign_in

    get :show, params: { name: 'activities' }

    assert_response :success
    assert_select '.pb-modal__actions button.btn.pdf[data-action=?][data-url=?]',
                  'sop-modal#openReference', reference_data_runner_dsl_path('activities'), text: 'View File'
    assert_select '.pb-modal.pb-modal--xl h3', text: 'Downloaded Chart of Accounts File'
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
  end
end
