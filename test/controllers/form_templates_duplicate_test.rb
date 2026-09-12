# frozen_string_literal: true

require 'test_helper'

# The Duplicate button and the two endpoints its dialog talks to. What gets
# copied is Forms::DuplicatorTest's business; this covers the wiring.
class FormTemplatesDuplicateTest < ActionController::TestCase
  tests FormTemplatesController

  setup do
    session[:user] = { 'employee_id' => 1, 'email' => 'employee@example.com',
                       'first_name' => 'Test', 'last_name' => 'User' }
    @controller.define_singleton_method(:current_user_group_names) { Set['system_admins'] }
    @controller.define_singleton_method(:inbox_count) { 0 }
    @template = Forms::Template.create!(name: 'Dup Wiring', page_count: 2, submission_type: 'database')
  end

  test 'each card offers Duplicate and the page carries one dialog' do
    get :index

    assert_response :success
    assert_select "button[data-action='form-duplicate#open']" \
                  "[data-form-duplicate-preview-url-param='#{duplicate_preview_form_template_path(@template)}']",
                  text: 'Duplicate'
    assert_select "[data-form-duplicate-target='backdrop'][hidden]", count: 1
    assert_select "input[data-form-duplicate-target='selectAll']", count: 1
  end

  test 'the preview names the copy and reports what each box would copy' do
    get :duplicate_preview, params: { id: @template.id, name: 'Dup Wiring Copy', components: %w[workflow] },
                            format: :json

    body = response.parsed_body
    assert body['valid']
    assert_equal 'DupWiringCopyForm', body['class_name']
    assert_includes body['identity'], %w[Table dup_wiring_forms dup_wiring_copy_forms]
    assert_not body.dig('components', 'table', 'available')
  end

  test 'a duplicate under a taken name is refused without copying anything' do
    assert_no_difference -> { Forms::Template.count } do
      post :duplicate, params: { id: @template.id, name: 'dup wiring' }, format: :json
    end

    assert_response :unprocessable_entity
    assert(response.parsed_body['errors'].any? { |error| error.include?('already exists') })
  end
end
