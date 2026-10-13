# frozen_string_literal: true

require 'test_helper'

# A routing step's custom inbox button text: the builder shows one row per
# renamed button and posts the buttons and the labels as two lists.
class FormTemplatesButtonLabelsTest < ActionController::TestCase
  tests FormTemplatesController

  setup do
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }
    @template = Forms::Template.create!(name: 'Label Wiring', page_count: 2, submission_type: 'database')
  end

  def labels(keys, texts)
    step = ActionController::Parameters.new(button_label_keys: keys, button_label_texts: texts)
    @controller.send(:extract_step_button_labels, step)
  end

  test 'a step shows its own text on a renamed button and the stock text on the rest' do
    step = @template.routing_steps.create!(step_number: 1, routing_type: 'supervisor',
                                           button_labels: { 'approve' => 'Permit Printed', 'edit' => '' })

    texts = %w[approve edit view_pdf].map { |type| step.button_text(type) }

    assert_equal ['Permit Printed', 'Edit', 'View PDF'], texts
    assert_equal 'Approve', @template.button_text('approve')
    assert_equal({}, @template.routing_steps.create!(step_number: 2, routing_type: 'supervisor').button_labels)
  end

  test 'the edit page has a row for each renamed button' do
    @template.routing_steps.create!(step_number: 1, routing_type: 'supervisor',
                                    button_labels: { 'approve' => 'Permit Printed', 'reassign' => 'Hand Off' })
    @template.routing_steps.create!(step_number: 2, routing_type: 'supervisor')
    @template.update_columns(submission_type: 'approval')

    get :edit, params: { id: @template.id }

    assert_response :success
    rows = css_select('.routing-step-item .step-button-label-row').map do |row|
      [row.at_css('option[selected]')['value'], row.at_css('.step-button-label-text')['value']]
    end

    assert_equal [['approve', 'Permit Printed'], ['reassign', 'Hand Off'], ['approve', '']], rows.first(3)
    assert_select '.step-button-label-key option[value="status_dropdown"]', count: 0
    assert_select 'template#routing-step-template', count: 1
  end

  test 'posted rows pair each button with its label' do
    assert_equal({ 'approve' => 'Permit Printed', 'view_pdf' => 'Open' },
                 labels(%w[approve deny view_pdf], ['Permit Printed', '', ' Open ']))
  end

  test 'a row naming no renamable button is dropped' do
    assert_equal({}, labels(%w[status_dropdown bogus], %w[Status Other]))
    assert_equal({}, labels(nil, nil))
  end
end
