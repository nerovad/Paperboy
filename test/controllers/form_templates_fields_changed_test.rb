# frozen_string_literal: true

require 'test_helper'

# update rebuilds a form's fields, and rewrites its generated views, only when
# form_fields_changed? says the posted fields differ from the stored ones.
class FormTemplatesFieldsChangedTest < ActionController::TestCase
  tests FormTemplatesController

  LOOKUP = { table: 'employees', match_column: 'full_name', return_column: 'email' }.freeze
  POSTED = [
    { label: 'Name', field_type: 'text', page_number: '2' },
    { label: 'Email', field_type: 'email', page_number: '2', answer_mode: 'lookup', answer_lookup: LOOKUP },
    { label: 'Item', field_type: 'text', page_number: '2', repeatable: '1', repeat_min: '1', add_label: 'Add item' },
    { label: 'Notes', field_type: 'text_box', page_number: '2', rows: '4', restricted_to_type: 'group',
      restricted_to_group_id: '19', restricted_to_org_filter_level: 'agency', visible_to_filler: '1' },
    { label: 'Summary', field_type: 'text_box', page_number: '2' },
    { label: 'Unit', field_type: 'dropdown', page_number: '2', data_source: 'units', data_source_column: 'name' }
  ].freeze

  setup do
    @template = Forms::Template.create!(name: 'Change Probe', page_count: 2, submission_type: 'database')
    post_fields(POSTED)
    @controller.send(:rebuild_form_fields)
    @template.form_fields.reset
  end

  def post_fields(fields)
    @controller.params = ActionController::Parameters.new(fields: fields)
    @controller.instance_variable_set(:@form_template, @template)
  end

  def changed?(index = nil, **overrides)
    post_fields(POSTED.each_with_index.map { |field, at| at == index ? field.merge(overrides) : field })
    @controller.send(:form_fields_changed?)
  end

  test 'fields posted back as they were stored are not a change' do
    assert_equal %w[answer_lookup], @template.form_fields.find_by!(label: 'Email').options.keys
    assert_not changed?
  end

  test 'a change to a lookup, a repeat setting, a restriction or visibility is a change' do
    assert changed?(1, answer_lookup: LOOKUP.merge(return_column: 'phone'))
    assert changed?(2, add_label: 'Add another')
    assert changed?(3, restricted_to_group_id: '20')
    assert changed?(3, restricted_to_type: 'none')
    assert changed?(3, visible_to_filler: '0')
    assert changed?(3, rows: '6')
  end
end
