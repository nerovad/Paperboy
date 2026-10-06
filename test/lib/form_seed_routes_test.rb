# frozen_string_literal: true

require 'test_helper'

# db/forms.yml also carries the routes of a routing step that has several
# (see Paperboy::FormSeed::Workflow), nested under the step.
class FormSeedRoutesTest < ActiveSupport::TestCase
  CLASS_NAME = 'SeedRoutesProbeForm'

  def row(routes)
    { 'class_name' => CLASS_NAME, 'name' => 'Seed Routes Probe', 'page_count' => 2, 'submission_type' => 'approval',
      'fields' => [],
      'routing_steps' => [{ 'step_number' => 1, 'routing_type' => 'multiple', 'deny_rule' => 'task',
                            'inbox_buttons' => [], 'routes' => routes }] }
  end

  def sync(data)
    Paperboy::FormSeed::Sync.form(data, dry: false, prune: false)
  end

  def step
    Forms::Template.find_by(class_name: CLASS_NAME).routing_steps.sole
  end

  setup do
    @group = Group.create!(group_name: 'Seed_Routes_Reviewers')
    @routes = [{ 'routing_type' => 'supervisor', 'label' => 'Pending Manager Approval' },
               { 'routing_type' => 'group', 'group' => 'Seed_Routes_Reviewers' }]
  end

  test 'a step arrives with its routes and rules' do
    log = sync(row(@routes))

    assert_empty log.grep(/\A!/), log.join("\n")
    assert_equal 'task', step.deny_rule
    assert_equal [nil, @group.id], step.routes.map(&:group_id)
  end

  test 'a second sync of the same file changes nothing' do
    sync(row(@routes))

    assert_empty sync(row(@routes))
  end

  test 'routes here are made to match the file' do
    sync(row(@routes))

    assert_includes sync(row(@routes.first(1))), "~ #{CLASS_NAME} routing step 1: routes"
    assert_equal ['Pending Manager Approval'], step.routes.map(&:label)
  end

  test 'a route for a group this database does not have is held back' do
    log = sync(row([{ 'routing_type' => 'group', 'group' => 'No_Such_Group' }]))

    assert_match(/No_Such_Group is not a group/, log.grep(/\A!/).join)
  end
end
