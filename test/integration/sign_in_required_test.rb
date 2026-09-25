# frozen_string_literal: true

require 'test_helper'

# Every page needs a signed-in user (ApplicationController#require_sign_in).
# The case that surfaced it: the Teams "View in Paperboy" button on a Critical
# Information Report opened the incident for anyone holding the link, and Back
# from there reached the rest of the app.
class SignInRequiredTest < ActionDispatch::IntegrationTest
  PASSWORD = 'correct horse battery staple'

  test 'a signed-out visitor following an incident link is sent to sign in' do
    get critical_information_reporting_path(42)

    assert_redirected_to root_path
    assert_equal 'Please sign in to continue.', flash[:alert]
  end

  test 'signing in lands back on the page that was asked for' do
    contractor = create_contractor

    get critical_information_reporting_path(42)
    post contractor_login_path, params: { email: contractor.email, password: PASSWORD }

    assert_redirected_to critical_information_reporting_path(42)
  end

  test 'with nothing remembered, signing in goes home' do
    contractor = create_contractor

    post contractor_login_path, params: { email: contractor.email, password: PASSWORD }

    assert_redirected_to root_path
  end

  test 'the inbox and submissions are closed to signed-out visitors' do
    [inbox_queue_path, submissions_path, settings_path].each do |path|
      get path

      assert_redirected_to root_path, path
    end
  end

  test 'a signed-out form post is turned away without being remembered' do
    patch critical_information_reporting_path(42), params: { critical_information_reporting: { urgency: 'High' } }

    assert_redirected_to root_path
    assert_nil session[:return_to]
  end

  test 'a signed-out JSON request gets a 401' do
    get submissions_status_options_path, as: :json

    assert_response :unauthorized
  end

  test 'the landing page and the sign-in pages stay open' do
    [root_path, contractor_login_path, new_contractor_password_path].each do |path|
      get path

      assert_response :success, path
    end
  end

  test 'signed-in pages are not cached, so Back after signing out asks again' do
    contractor = create_contractor
    post contractor_login_path, params: { email: contractor.email, password: PASSWORD }

    get settings_path

    assert_response :success
    assert_equal 'no-store', response.headers['Cache-Control']
    assert_select 'meta[name="turbo-cache-control"][content="no-cache"]'
  end

  private

  def create_contractor
    Contractor.create!(first_name: 'Casey', last_name: 'Contract', email: "casey#{SecureRandom.hex(3)}@example.com",
                       agency: '10', unit: '1001', supervisor_id: '1', work_phone: '555-0100',
                       expires_at: 1.month.from_now, password: PASSWORD)
  end
end
