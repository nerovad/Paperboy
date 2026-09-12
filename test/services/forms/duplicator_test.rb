# frozen_string_literal: true

require 'test_helper'

# Duplicate's database half. The source here is a template with no generated
# code or table, so only the row-level pieces are available and nothing is
# written to disk or migrated -- the file and table halves are covered by
# their own tests and by the rename they share.
module Forms
  class DuplicatorTest < ActiveSupport::TestCase
    ROW_COMPONENTS = %w[definition workflow access visibility sidebar].freeze

    setup do
      @source = Forms::Template.create!(name: 'Dup Probe', page_count: 3, page_headers: ['Details'],
                                        submission_type: 'database', inbox_buttons: %w[view_pdf edit])
      trigger = @source.form_fields.create!(label: 'Injured?', field_type: 'yes_no', page_number: 3, position: 0)
      @source.form_fields.create!(label: 'Body part', field_type: 'text', page_number: 3, position: 1,
                                  conditional_field_id: trigger.id, conditional_values: ['Yes'])
      @group = Group.create!(Group_Name: "Dup_Probe_#{SecureRandom.hex(3)}")
    end

    def duplicator(name: 'Dup Probe Copy', components: ROW_COMPONENTS)
      Duplicator.new(source: @source, name: name, components: components, actor_id: 42)
    end

    test 'the copy takes its class from the new name' do
      assert_equal 'DupProbeCopyForm', duplicator.class_name
    end

    test 'a blank name, a taken name or a name that cannot be a class is refused' do
      [['', 'Give the copy a name.'], ['dup probe', 'already exists'], ['2026 Probe', 'start with a letter']]
        .each do |name, message|
        subject = duplicator(name: name)

        assert_not subject.valid?, name
        assert(subject.errors.any? { |error| error.include?(message) }, "#{name}: #{subject.errors.inspect}")
      end
    end

    test 'pieces with nothing to copy are unavailable and dropped from the set' do
      subject = duplicator(components: Duplicator::Components::KEYS)

      assert_includes subject.unavailable, 'table'
      assert_includes subject.unavailable, 'controller'
      assert_not_includes subject.components, 'table'
      assert subject.valid?, subject.errors.inspect
    end

    test 'copies fields with their conditions pointing at the copy’s own fields' do
      copy = duplicator.call.template

      assert_equal 'DupProbeCopyForm', copy.class_name
      assert_equal 42, copy.created_by
      assert_not copy.archived
      assert_not_equal @source.reference_prefix, copy.reference_prefix

      body_part = copy.form_fields.find_by!(field_name: 'body_part')
      assert_equal copy.id, body_part.conditional_field.form_template_id
      assert_equal 'injured', body_part.conditional_field.field_name
      assert_equal ['Yes'], body_part.conditional_values
    end

    test 'copies the workflow, re-pointing routing steps at the copy’s statuses' do
      status = @source.statuses.create!(name: 'Step 1 Pending', key: 'step_1_pending', category: 'pending',
                                        auto_generated: true)
      @source.routing_steps.create!(step_number: 1, routing_type: 'supervisor', form_template_status_id: status.id)
      @source.email_steps.create!(trigger_event: 'submit', recipient_type: 'submitter',
                                  subject: 'Your Dup Probe was received')
      @source.update!(submission_type: 'approval')

      copy = duplicator.call.template

      step = copy.routing_steps.sole
      assert_equal copy.statuses.find_by!(key: 'step_1_pending').id, step.form_template_status_id
      assert_equal 'Your Dup Probe Copy was received', copy.email_steps.sole.subject
      assert_equal %w[view_pdf edit], copy.enabled_inbox_buttons
    end

    test 'copies ACL grants and visibility grants under the copy’s own keys' do
      GroupPermission.create!(GroupID: @group.GroupID, Permission_Type: 'form', Permission_Key: @source.id.to_s)
      GroupPermission.create!(GroupID: @group.GroupID, Permission_Type: 'submission_action',
                              Permission_Key: 'edit:DupProbeForm')
      OrgPermission.create!(agency_id: 'HCA', permission_type: 'form', permission_key: @source.id.to_s)
      Forms::VisibilityGrant.create!(form_type: 'DupProbeForm', grantee_type: 'group', group_id: @group.GroupID)

      copy = duplicator.call.template

      assert GroupPermission.exists?(GroupID: @group.GroupID, Permission_Type: 'form', Permission_Key: copy.id.to_s)
      assert GroupPermission.exists?(GroupID: @group.GroupID, Permission_Key: 'edit:DupProbeCopyForm')
      assert OrgPermission.exists?(agency_id: 'HCA', permission_type: 'form', permission_key: copy.id.to_s)
      assert Forms::VisibilityGrant.exists?(form_type: 'DupProbeCopyForm', group_id: @group.GroupID)
    end

    test 'leaving the sidebar unticked creates the copy archived, and says so' do
      result = duplicator(components: ROW_COMPONENTS - %w[sidebar]).call

      assert result.template.archived
      assert(result.notes.any? { |note| note.include?('archived') })
    end

    test 'a failure after the rows are written removes them again' do
      subject = duplicator
      subject.code.define_singleton_method(:call) { |_journal| raise Duplicator::Error, 'disk full' }

      assert_raises(Duplicator::Error) { subject.call }

      assert_not Forms::Template.exists?(class_name: 'DupProbeCopyForm')
      assert_not Forms::Field.joins(:form_template).exists?(form_templates: { class_name: 'DupProbeCopyForm' })
    end
  end
end
