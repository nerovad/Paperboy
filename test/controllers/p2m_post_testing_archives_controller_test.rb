# frozen_string_literal: true

require 'test_helper'

class P2mPostTestingArchivesControllerTest < ActionController::TestCase
  tests P2m::PostTestingArchivesController

  test 'shows the fixed quarter and the files for each job' do
    sign_in
    jobs = [job]

    P2m::PostTestingArchive.stub(:new, archive(preview: jobs)) { get :show }

    assert_response :success
    assert_select 'h1', text: 'Post Testing Archive'
    assert_match '7/1/2026 through 9/30/2026', response.body
    assert_select 'button.btn.approve', text: 'Archive', count: 1
    assert_select 'button', text: 'Reset Data', count: 0
    assert_select '.p2m-maildat-row', text: /51780767/, count: 1
    assert_select '.p2m-maildat-row', text: /incomplete/, count: 1
    assert_select '.p2m-maildat-detail[hidden] li', text: '51780767-a.pdf', count: 1
    refute_match 'GSABSS', response.body
  end

  test 'shows an empty quarter without an archive button' do
    sign_in

    P2m::PostTestingArchive.stub(:new, archive(preview: [])) { get :show }

    assert_response :success
    assert_match 'No historical jobs were found', response.body
    assert_select 'button', text: 'Archive', count: 0
  end

  test 'reports a search failure without archiving' do
    sign_in
    failed = Object.new
    failed.define_singleton_method(:preview) { raise 'fd failed' }

    P2m::PostTestingArchive.stub(:new, failed) { get :show }

    assert_response :success
    assert_equal 'Historical search failed: fd failed', flash[:alert]
    assert_select 'button', text: 'Archive', count: 0
  end

  test 'archives one OMS as JSON' do
    sign_in
    result = {
      'oms_number' => '51780767', 'error' => false, 'moved' => ['51780767-a.pdf'],
      'removed' => [], 'message' => 'Moved 1 file for 51780767.'
    }

    P2m::PostTestingArchive.stub(:new, archive(move: result)) do
      post :create, params: { oms_number: '51780767' }, format: :json
    end

    assert_response :success
    assert_equal 'Moved 1 file for 51780767.', response.parsed_body.fetch('message')
  end

  test 'returns the stopped OMS so the screen can continue with the next job' do
    sign_in
    result = {
      'oms_number' => '51780767', 'error' => true, 'moved' => [],
      'removed' => [],
      'message' => 'Stopped 51780767 at 51780767-a.pdf because Processed has different contents.'
    }

    P2m::PostTestingArchive.stub(:new, archive(move: result)) do
      post :create, params: { oms_number: '51780767' }, format: :json
    end

    assert_response :unprocessable_content
    assert_match 'Stopped 51780767', response.parsed_body.fetch('message')
  end

  private

  def job
    {
      'oms_number' => '51780767', 'mail_date' => '2026-07-15', 'status' => 'incomplete',
      'detail' => 'Missing inputs.', 'files' => ['51780767-a.pdf'], 'count' => 1
    }
  end

  def archive(preview: nil, move: nil)
    responder = Object.new
    responder.define_singleton_method(:preview) { preview }
    responder.define_singleton_method(:move) { |_oms_number| move }
    responder
  end

  def sign_in
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
  end
end
