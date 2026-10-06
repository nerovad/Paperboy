# frozen_string_literal: true

require 'test_helper'

module Forms
  class TemplateStepRouteTest < ActiveSupport::TestCase
    setup do
      @template = Forms::Template.create!(name: 'Route Probe', class_name: 'RouteProbeForm',
                                          page_count: 2, submission_type: 'database')
      @step = @template.routing_steps.create!(step_number: 1, routing_type: 'multiple')
    end

    test 'a route needs the target its routing type names' do
      assert_not @step.routes.build(routing_type: 'employee').valid?
      assert_not @step.routes.build(routing_type: 'group').valid?
      assert_predicate @step.routes.build(routing_type: 'supervisor'), :valid?
    end

    test 'a route cannot itself fan out' do
      assert_not @step.routes.build(routing_type: 'multiple').valid?
    end

    test 'the task label is the one typed, or names the target' do
      assert_equal 'Waiting on Quote', @step.routes.build(routing_type: 'supervisor', label: 'Waiting on Quote').task_label
      assert_equal 'Sent to Supervisor', @step.routes.build(routing_type: 'supervisor').task_label
    end

    test 'a step with several routes is named after all of them' do
      @step.routes.create!(position: 0, routing_type: 'supervisor')
      @step.routes.create!(position: 1, routing_type: 'supervisor')

      assert_equal 'Sent to Supervisor and Supervisor', @step.pending_display_name
    end

    test 'the rules default to every route approving and one deny denying' do
      assert_equal %w[all form], [@step.completion_rule, @step.deny_rule]
      assert_not @step.tap { |step| step.completion_rule = 'most' }.valid?
    end

    test 'deleting the step deletes its routes' do
      @step.routes.create!(position: 0, routing_type: 'supervisor')

      assert_difference -> { Forms::TemplateStepRoute.count }, -1 do
        @step.destroy
      end
    end
  end
end
