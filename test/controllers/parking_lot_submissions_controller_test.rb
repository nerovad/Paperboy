# frozen_string_literal: true

require 'test_helper'

class ParkingLotSubmissionsControllerTest < ActionController::TestCase
  tests Forms::ParkingLotSubmissionsController

  # Parking Lot is one of the submit-only forms: it defines new, create,
  # index, show, pdf, approve and deny, and no edit or update. That made it
  # the first casualty when Forms::BaseController guarded editing with
  # `only: %i[edit update]` — Rails refuses an :only naming an action the
  # controller hasn't got, so every request here raised, including these
  # two. Both actions below answer without touching the database, so they
  # stay a cheap guard against the callback chain breaking again.

  test 'index redirects to the inbox queue' do
    get :index

    assert_redirected_to inbox_queue_path
  end

  test 'new redirects to login when nobody is signed in' do
    get :new

    assert_redirected_to login_path
    assert_equal 'Please sign in to start a submission.', flash[:alert]
  end
end
