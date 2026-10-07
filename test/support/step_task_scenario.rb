# frozen_string_literal: true

# An ID badge request standing at a routing step with three routes: a manager,
# a vendor contact and the accounting group. Shared by the tests of the
# multi-route engine (TrackableStatus::StepTasks), which each look at one side
# of it. IdBadgeRequestForm is used because it has two step statuses to move
# between.
module StepTaskScenario
  extend ActiveSupport::Concern

  SUBMITTER = '900'
  MANAGER = '500'
  VENDOR = '501'
  ACCOUNTANT = '502'
  GROUP_ID = 77

  included do
    setup do
      @template = Forms::Template.create!(name: 'ID Badge Request', class_name: 'IdBadgeRequestForm',
                                          page_count: 2, submission_type: 'database')
      @template.statuses.create!(name: 'Denied', key: 'denied', category: 'denied', is_end: true, position: 9)
      @template.statuses.create!(name: 'Approved', key: 'approved', category: 'approved', is_end: true, position: 8)
      IdBadgeRequestForm.remove_instance_variable(:@central_status_definitions) if
        IdBadgeRequestForm.instance_variable_defined?(:@central_status_definitions)

      @step = @template.routing_steps.create!(step_number: 1, routing_type: 'multiple')
      @step.routes.create!(position: 0, routing_type: 'employee', employee_id: MANAGER.to_i,
                           label: 'Pending Manager Approval')
      @step.routes.create!(position: 1, routing_type: 'employee', employee_id: VENDOR.to_i,
                           label: 'Waiting on Vendor Approval')
      @step.routes.create!(position: 2, routing_type: 'group', group_id: GROUP_ID, label: 'Waiting on Quote')

      @form = IdBadgeRequestForm.create!(name: 'Pat Example', email: 'pat@example.com', employee_id: SUBMITTER)
    end

    teardown do
      Current.reset
      IdBadgeRequestForm.remove_instance_variable(:@central_status_definitions) if
        IdBadgeRequestForm.instance_variable_defined?(:@central_status_definitions)
    end
  end

  # Runs the block with the accounting group resolved without a GSABSS lookup.
  def routed(&block)
    EmployeeGroup.stub(:member_ids, [ACCOUNTANT], &block)
  end

  def as(employee_id)
    Current.user = { 'employee_id' => employee_id, 'first_name' => 'Emp', 'last_name' => employee_id }
  end

  def start
    routed { @form.start_approval! }
  end

  def approve(employee_id)
    as(employee_id)
    routed { @form.advance_approval! }
    @form.reload
  end

  def deny(employee_id)
    as(employee_id)
    routed { @form.denied! }
    @form.reload
  end

  def states
    @form.step_tasks.ordered.map(&:state)
  end
end
