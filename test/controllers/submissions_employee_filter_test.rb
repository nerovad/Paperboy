# frozen_string_literal: true

require 'test_helper'

# The Employee filter on Submissions. Whoever gets the filter at all starts on
# All — everything they may see — and picks Me to narrow to their own.
class SubmissionsEmployeeFilterTest < ActionController::TestCase
  tests SubmissionsController

  ME = '102989'
  REPORT = '204455'

  setup do
    session[:user] = { 'employee_id' => ME.to_i, 'email' => 'maria.acosta@example.com' }
    @controller.define_singleton_method(:inbox_count) { 0 }
    @controller.define_singleton_method(:current_user_group_ids) { [] }
  end

  def sign_in_as(groups: [])
    @controller.define_singleton_method(:current_user_group_names) { Set.new(groups) }
  end

  def scope_for(filter_employee, subordinates: [REPORT])
    Employee.stub(:subordinate_ids, subordinates) do
      get :index, params: { filter_employee: filter_employee }.compact
    end
    assert_response :success
    @controller.instance_variable_get(:@scoped_employee_ids)
  end

  test 'a supervisor starts on All: themselves and their reporting chain' do
    sign_in_as

    assert_equal [ME, REPORT], scope_for(nil)
  end

  test 'Me narrows a supervisor to their own submissions' do
    sign_in_as

    assert_equal [ME], scope_for('me')
  end

  test 'the old all value still means All' do
    sign_in_as

    assert_equal [ME, REPORT], scope_for('all')
  end

  test 'a system admin starts on All with no employee restriction' do
    sign_in_as(groups: ['system_admins'])

    assert_nil scope_for(nil, subordinates: [])
  end

  test 'someone without the filter only ever sees their own' do
    sign_in_as

    assert_equal [ME], scope_for(nil, subordinates: [])
  end

  test 'All is listed first and selected, with Me just below it' do
    sign_in_as
    report = Employee.new(id: REPORT, first_name: 'Ana', last_name: 'Ruiz')
    reports = Struct.new(:rows) { def order(*) = rows }.new([report])

    Employee.stub(:where, reports) { scope_for(nil) }

    options = css_select('select#filter_employee option').first(3).map { |o| [o.text, o['value']] }
    assert_equal [['All', ''], %w[Me me], ['Ruiz, Ana', REPORT]], options
    assert_equal '', css_select('select#filter_employee option[selected]').first&.[]('value').to_s
  end
end
