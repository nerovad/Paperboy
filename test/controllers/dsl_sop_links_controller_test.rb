# frozen_string_literal: true

require 'test_helper'

class DslSopLinksControllerTest < ActionController::TestCase
  tests DataRunner::DslsController

  test 'DSL with an SOP renders a download instructions modal' do
    sign_in

    get :show, params: { name: 'usps' }

    assert_response :success
    assert_select 'button.btn.info[data-action=?]', 'sop-modal#open', text: 'How to Download'
    assert_select '.pb-modal[role=?][aria-modal=?]', 'dialog', 'true'
    assert_select '.dsl-sop ol li', count: 4
    assert_select '.pb-modal__actions a.btn.pdf[href=?]',
                  'https://gateway.usps.com/eAdmin/view/signin', text: 'Open'
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
                  'sop-modal#openReference', reference_data_runner_dsl_path('oversized'), text: 'Open'
    assert_select '.pb-modal.pb-modal--xl[role=?][aria-modal=?]', 'dialog', 'true'
  end

  private

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
  end
end
