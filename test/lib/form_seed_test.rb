# frozen_string_literal: true

require 'test_helper'

# db/forms.yml carries a form from dev to stage and prod, and dev is the source
# of truth: a form that is missing is created, and its workflow is made to
# match the file. These cover the workflow half -- the rows that used to stay
# behind in whichever database they were typed into.
class FormSeedTest < ActiveSupport::TestCase
  Sync = Paperboy::FormSeed::Sync

  CLASS_NAME = 'SeedProbeForm'

  def row(overrides = {})
    { 'class_name' => CLASS_NAME, 'name' => 'Seed Probe', 'page_count' => 2, 'submission_type' => 'approval',
      'inbox_buttons' => %w[approve deny], 'fields' => [],
      'statuses' => [{ 'key' => 'in_progress', 'name' => 'In Progress', 'category' => 'pending', 'position' => 0, 'is_initial' => true },
                     { 'key' => 'approved', 'name' => 'Approved', 'category' => 'approved', 'position' => 1, 'is_end' => true },
                     { 'key' => 'denied', 'name' => 'Denied', 'category' => 'denied', 'position' => 2, 'is_end' => true }],
      'routing_steps' => [{ 'step_number' => 1, 'routing_type' => 'supervisor', 'inbox_buttons' => [] },
                          { 'step_number' => 2, 'routing_type' => 'group', 'group' => 'Seed_Probe_Reviewers', 'inbox_buttons' => [] }],
      'emails' => [{ 'kind' => 'new_submission', 'subject' => 'Filed: {{reference}}', 'body' => 'From dev' }],
      'email_steps' => [{ 'trigger_event' => 'submit', 'recipient_type' => 'custom_email', 'custom_email' => 'desk@example.com',
                          'attach_pdf' => true, 'attach_media' => false, 'position' => 0 }],
      'copy_recipients' => [{ 'recipient_type' => 'supervisor', 'trigger_event' => 'approval', 'position' => 0 }] }.merge(overrides)
  end

  def sync(data, dry: false)
    Sync.form(data, dry: dry, prune: false)
  end

  def template
    Forms::Template.find_by(class_name: CLASS_NAME)
  end

  setup { @group = Group.create!(group_name: 'Seed_Probe_Reviewers') }

  test 'a form this database does not have arrives with its workflow' do
    log = sync(row)

    assert_empty log.grep(/\A!/), log.join("\n")
    assert_includes log, "+ form   #{CLASS_NAME}"
    assert_equal %w[in_progress approved denied], template.statuses.map(&:key)
    assert_equal [nil, @group.id], template.routing_steps.map(&:group_id)
    assert_equal 'From dev', template.emails.sole.body
    assert_equal 'desk@example.com', template.email_steps.sole.custom_email
    assert_equal 'supervisor', template.copy_recipients.sole.recipient_type
    assert_equal %w[approve deny], template.inbox_buttons
  end

  test 'a second sync of the same file changes nothing' do
    sync(row)
    assert_empty sync(row)
  end

  test 'workflow here is made to match the file, in place' do
    sync(row)
    email_id = template.emails.sole.id
    template.statuses.create!(key: 'on_hold', name: 'On Hold', category: 'pending', position: 9)
    template.email_steps.create!(trigger_event: 'approved', recipient_type: 'submitter', position: 1)

    log = sync(row('emails' => [{ 'kind' => 'new_submission', 'subject' => 'Filed: {{reference}}', 'body' => 'Reworded in dev' }],
                   'copy_recipients' => []))

    assert_equal ["~ #{CLASS_NAME} email new_submission: body", "- #{CLASS_NAME} status on_hold",
                  "- #{CLASS_NAME} email rule 2", "- #{CLASS_NAME} copy recipient 1"].sort, log.sort
    assert_equal [email_id, 'Reworded in dev'], [template.emails.sole.id, template.emails.sole.body]
    assert_equal 3, template.statuses.count
    assert_equal 1, template.email_steps.count
    assert_empty template.copy_recipients
  end

  test 'a list the file does not carry is left alone' do
    sync(row)
    assert_empty sync(row.except('emails', 'statuses', 'routing_steps', 'email_steps', 'copy_recipients'))
    assert_equal 1, template.emails.count
    assert_equal 3, template.statuses.count
  end

  test 'template columns follow the file' do
    sync(row)
    log = sync(row('name' => 'Seed Probe Renamed', 'inbox_buttons' => %w[approve]))

    assert_equal ["~ form   #{CLASS_NAME}: name, inbox_buttons"], log
    assert_equal ['Seed Probe Renamed', %w[approve]], [template.name, template.inbox_buttons]
  end

  test 'a dry run reports the plan and writes nothing' do
    log = sync(row, dry: true)

    assert_includes log, "+ form   #{CLASS_NAME}"
    assert_includes log, "+ #{CLASS_NAME} routing step 2"
    assert_nil template
  end

  test 'a row for a group that is not here is held back and what it would replace is kept' do
    sync(row)
    steps = row['routing_steps'].dup
    steps[1] = steps[1].merge('group' => 'No_Such_Group')

    log = sync(row('routing_steps' => steps))

    assert_equal 1, log.size
    assert_match(/\A! #{CLASS_NAME} routing step 2: group No_Such_Group is not a group in this database/, log.first)
    assert_equal @group.id, template.routing_steps.last.group_id
  end

  test 'a dump survives the file and rebuilds the same form elsewhere' do
    sync(row)
    groups = { @group.id => @group.group_name }
    dumped = YAML.safe_load(Paperboy::FormSeed.form_row(template, groups).to_yaml)
    template.destroy!
    @group.destroy!
    elsewhere = Group.create!(group_name: 'Seed_Probe_Reviewers')

    log = sync(dumped)

    assert_empty log.grep(/\A!/), log.join("\n")
    assert_equal dumped, Paperboy::FormSeed.form_row(template, { elsewhere.id => elsewhere.group_name })
  end
end
