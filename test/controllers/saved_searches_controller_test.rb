# frozen_string_literal: true

require 'test_helper'

# A saved search is only as good as the filters it remembers. The Submissions
# filter set is not fixed — column filters follow the viewer's layout and custom
# columns mint their own params — so whatever `filter_` params the page sent
# must come back when the search is loaded.
class SavedSearchesControllerTest < ActionController::TestCase
  setup do
    session[:user] = { 'employee_id' => 102_989 }
  end

  test 'keeps every filter the page sent, including layout-dependent ones' do
    post :create, params: {
      name: 'Open parking in my unit',
      filter_type: 'Parking Lot',
      filter_status: 'Pending',
      filter_unit: 'ADM',
      filter_employee: 'all',
      filter_reference: 'PLS',
      filter_date_from: '2026-01-01',
      filter_leave_of_absence_form_reason: 'Medical',
      sort_by: 'updated_at',
      sort_direction: 'asc'
    }

    saved = SavedSearch.find_by!(employee_id: '102989', name: 'Open parking in my unit')

    assert_equal({ 'filter_type' => 'Parking Lot', 'filter_status' => 'Pending',
                   'filter_unit' => 'ADM', 'filter_employee' => 'all',
                   'filter_reference' => 'PLS', 'filter_date_from' => '2026-01-01',
                   'filter_leave_of_absence_form_reason' => 'Medical',
                   'sort_by' => 'updated_at', 'sort_direction' => 'asc' },
                 saved.filters)
    assert_redirected_to submissions_path(saved.filters.merge(saved_search_id: saved.id))
  end

  test 'drops blank filters and anything that is not a filter' do
    post :create, params: { name: 'Mine', filter_status: '', filter_type: 'Parking Lot',
                            saved_search_id: '7', page: '3' }

    assert_equal({ 'filter_type' => 'Parking Lot' },
                 SavedSearch.find_by!(employee_id: '102989', name: 'Mine').filters)
  end

  test 'keeps multi-value filters as lists' do
    post :create, params: { name: 'Two forms', filter_type: ['Parking Lot', 'Probation Transfer'] }

    assert_equal({ 'filter_type' => ['Parking Lot', 'Probation Transfer'] },
                 SavedSearch.find_by!(employee_id: '102989', name: 'Two forms').filters)
  end
end
