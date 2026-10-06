# frozen_string_literal: true

require 'test_helper'

# The form builder's side of a routing step with several routes: the edit page
# hands the routes to the builder as one JSON value, and gets them back the
# same way.
class FormTemplatesStepRoutesTest < ActionController::TestCase
  tests FormTemplatesController

  MULTIPLE = { routing_type: 'multiple', completion_rule: 'any', deny_rule: 'task' }.freeze

  setup do
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  def posted(step)
    @controller.params = ActionController::Parameters.new(routing_steps: [step])
    @controller.send(:settle_multiple_route_steps)
    @controller.params[:routing_steps].first
  end

  def routes_json(*routes)
    routes.to_json
  end

  test 'the edit page carries a step’s routes and rules' do
    template = Forms::Template.create!(name: 'Route Wiring', page_count: 2, submission_type: 'database')
    step = template.routing_steps.create!(step_number: 1, **MULTIPLE)
    step.routes.create!(position: 0, routing_type: 'supervisor', label: 'Pending Manager Approval')
    step.routes.create!(position: 1, routing_type: 'employee', employee_id: 501)
    template.update_columns(submission_type: 'approval')

    get :edit, params: { id: template.id }

    assert_response :success
    assert_select "select[name='routing_steps[][routing_type]'] option[value='multiple'][selected]", count: 1
    assert_select "select[name='routing_steps[][completion_rule]'] option[value='any'][selected]", count: 1
    assert_select "select[name='routing_steps[][deny_rule]'] option[value='task'][selected]", count: 1
    assert_select 'template#step-route-template', count: 1
    posted_routes = JSON.parse(css_select("input[name='routing_steps[][routes_json]']").first['value'])

    assert_equal ['Pending Manager Approval', nil], posted_routes.pluck('label')
    assert_equal [nil, 501], posted_routes.pluck('employee_id')
  end

  test 'posted routes keep only the columns their type uses' do
    step = posted(MULTIPLE.merge(routes_json: routes_json(
      { routing_type: 'employee', employee_id: '501', group_id: '9', label: ' Vendor ' },
      { routing_type: 'supervisor', label: '' }
    )))

    assert_equal [{ routing_type: 'employee', employee_id: 501, group_id: nil, org_filter_level: nil,
                    authorization_service_type: nil, label: 'Vendor' },
                  { routing_type: 'supervisor', employee_id: nil, group_id: nil, org_filter_level: nil,
                    authorization_service_type: nil, label: nil }],
                 @controller.send(:step_route_attrs, step)
    assert_equal({ completion_rule: 'any', deny_rule: 'task' }, @controller.send(:step_rules, step))
  end

  test 'a route with no target chosen is left out' do
    step = posted(MULTIPLE.merge(routes_json: routes_json(
      { routing_type: 'employee', employee_id: '' }, { routing_type: 'supervisor' }, { routing_type: 'supervisor' }
    )))

    assert_equal %w[supervisor supervisor], @controller.send(:step_route_attrs, step).pluck(:routing_type)
  end

  test 'a step left with one route is saved as the ordinary step it describes' do
    step = posted(MULTIPLE.merge(display_name: '', routes_json: routes_json(
      { routing_type: 'employee', employee_id: '501', label: 'Vendor' }
    )))

    assert_equal %w[employee 501 Vendor], step.values_at(:routing_type, :employee_id, :display_name)
    assert_empty @controller.send(:step_route_attrs, step)
    assert_equal({ completion_rule: 'all', deny_rule: 'form' }, @controller.send(:step_rules, step))
  end

  test 'a step left with no routes is dropped' do
    assert_equal '', posted(MULTIPLE.merge(routes_json: 'not json'))[:routing_type]
  end
end
