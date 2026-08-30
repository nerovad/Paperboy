# frozen_string_literal: true

require 'test_helper'

# Reference lookup — what the quick search's "Open submission PLS-845" row
# lands on. The row itself only recognises the shape of a reference; every
# question with an answer (does this form exist, does this record exist, may
# this person see it) is settled here.
class SubmissionsLookupControllerTest < ActionController::TestCase
  tests SubmissionsController

  setup do
    session[:user] = {
      'employee_id' => 102_989,
      'email' => 'maria.acosta@example.com',
      'first_name' => 'Maria',
      'last_name' => 'Acosta'
    }
    sign_in_as(groups: ['system_admins'])
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  def sign_in_as(groups: [])
    @controller.define_singleton_method(:current_user_group_names) { Set.new(groups) }
    @controller.define_singleton_method(:current_user_group_ids) { [] }
  end

  # The whole point: a number typed into the palette lands on the submission,
  # not on a list with the submission somewhere in it.
  test 'a reference goes straight to the submission it names' do
    request = probation_transfer_requests(:one)

    get :lookup, params: { reference: "PTR-#{request.id}" }

    assert_redirected_to probation_transfer_request_path(request)
  end

  test 'the prefix is read case-insensitively and the dash is optional' do
    request = probation_transfer_requests(:one)

    get :lookup, params: { reference: "ptr#{request.id}" }

    assert_redirected_to probation_transfer_request_path(request)
  end

  # A bare id names one record per form type, so it belongs to no single one of
  # them. Submissions filtered by it is the honest answer — the same list the
  # Reference column's search box produces.
  test 'a bare id falls back to Submissions filtered by it' do
    get :lookup, params: { reference: '845' }

    assert_redirected_to submissions_path(filter_reference: '845')
  end

  test 'a prefix no form uses falls back to the filtered list' do
    get :lookup, params: { reference: 'ZZZZ-1' }

    assert_redirected_to submissions_path(filter_reference: 'ZZZZ-1')
  end

  test 'a reference naming no record falls back to the filtered list' do
    get :lookup, params: { reference: 'PTR-999999999' }

    assert_redirected_to submissions_path(filter_reference: 'PTR-999999999')
  end

  test 'a query that is not a reference at all falls back to the filtered list' do
    get :lookup, params: { reference: 'leave of absence' }

    assert_redirected_to submissions_path(filter_reference: 'leave of absence')
  end

  test 'a missing reference falls back to the unfiltered list' do
    get :lookup

    assert_redirected_to submissions_path
  end

  # A reference is a guessable URL, so the lookup has to apply the same
  # visibility rules the Submissions list does rather than confirming a record
  # exists to anybody who types its number. Somebody it isn't shared with gets
  # the filtered list, which comes back empty.
  test 'a submission outside what the viewer may see is not opened' do
    sign_in_as(groups: [])
    request = probation_transfer_requests(:one)

    Employee.stub(:subordinate_ids, []) do
      get :lookup, params: { reference: "PTR-#{request.id}" }
    end

    assert_redirected_to submissions_path(filter_reference: "PTR-#{request.id}")
  end
end
