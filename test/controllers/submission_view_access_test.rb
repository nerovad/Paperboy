# frozen_string_literal: true

require 'test_helper'

# Every form's detail page, PDF and actions check Forms::SubmissionAccess, so a
# typed or guessed link opens nothing for someone the app doesn't already show
# the submission to. Probation Transfer stands in for every form: the guard
# lives in Forms::BaseController.
class SubmissionViewAccessTest < ActionController::TestCase
  tests Forms::ProbationTransferRequestsController

  setup do
    @request_record = probation_transfer_requests(:one)
    @request_record.update_columns(employee_id: '5001', supervisor_id: '5002')
    @controller.define_singleton_method(:current_user_group_names) { Set.new }
    @controller.define_singleton_method(:current_user_group_ids) { [] }
  end

  def sign_in_as(employee_id)
    session[:user] = { 'employee_id' => employee_id, 'email' => "#{employee_id}@example.com" }
  end

  test 'a stranger with the link is turned away from the page, the PDF and the actions' do
    sign_in_as('7001')

    Forms::SubmissionAccess.stub(:supervisor_chain, ->(*) { [] }) do
      get :show, params: { id: @request_record.id }
      assert_redirected_to submissions_path
      assert_equal "You don't have access to that submission.", flash[:alert]

      get :pdf, params: { id: @request_record.id }
      assert_redirected_to submissions_path

      assert_no_difference('ProbationTransferRequest.count') do
        delete :destroy, params: { id: @request_record.id }
      end
      assert_redirected_to submissions_path
    end
  end

  test 'the person it sits with may open it' do
    sign_in_as('5002')

    get :show, params: { id: @request_record.id }

    assert_response :success
  end
end
