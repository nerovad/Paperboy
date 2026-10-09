# frozen_string_literal: true

require 'test_helper'

# The Form Library page and the collection pages that share its action.
class FormLibraryControllerTest < ActionController::TestCase
  tests FormLibraryController

  setup do
    session[:user] = {
      'employee_id' => 102_989,
      'email' => 'maria.acosta@example.com',
      'first_name' => 'Maria',
      'last_name' => 'Acosta'
    }
    @controller.define_singleton_method(:current_user_group_names) { Set.new(['system_admins']) }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
    @controller.define_singleton_method(:inbox_count) { 0 }
  end

  # No template rows: the page lists the four legacy forms an admin always has.
  def without_templates(&block)
    with_templates([], &block)
  end

  def with_templates(templates, &block)
    # Asked twice per page: once for the list, once by the sidebar beside it.
    relation = Object.new
    relation.define_singleton_method(:includes) { |*| templates }

    Forms::Template.stub(:active, relation, &block)
  end

  def bike_locker
    Forms::Template.new(name: 'Bike Locker', class_name: 'BikeLockerForm', form_number: 'GSA-101',
                        form_type: 'Request', agency_id: 'GSA', tags: 'transportation,hr',
                        description: 'Reserve a bike locker').tap do |record|
      record.id = 42
      record.define_singleton_method(:form_fields) { [] }
    end
  end

  test 'index lists the forms the viewer may open' do
    without_templates { get :index }

    assert_response :success
    assert_select '.form-library__row', count: FormCatalog::LEGACY_FORMS.size
    assert_select '.form-library__row a', text: 'Leave of Absence'
  end

  test 'index narrows to what the search box asks for' do
    without_templates { get :index, params: { q: 'leave' } }

    assert_select '.form-library__row', count: 1
    assert_select 'a.clear-filters', count: 1
  end

  test 'a form shows its metadata and the facets offer it' do
    with_templates([bike_locker]) { get :index }

    assert_select '.form-library__number', text: 'GSA-101'
    assert_select '.form-library__tag', text: '#transportation'
  end

  test 'the sidebar holds the filters instead of the list of forms' do
    with_templates([bike_locker]) { get :index }

    assert_select '.sidebar select[name=filter_agency] option[value=GSA]', count: 1
    assert_select '.sidebar input[name=?][value=Request]', 'type[]', count: 1
    assert_select '.sidebar input[name=?][value=hr]', 'tag[]', count: 1
    assert_select '.sidebar input[name=q]', count: 1
    assert_select '.sidebar a.nav-link', text: 'Bike Locker', count: 0
  end

  test 'a collection that does not exist is a missing page' do
    without_templates { get :index, params: { collection: '999999' } }

    assert_response :not_found
  end

  test 'inside the library the sidebar button leads back to basic search' do
    without_templates { get :index }

    assert_select '.sidebar a.pb-advanced-trigger[href=?]', root_path, text: 'Basic Search'
    assert_select '.sidebar a.pb-advanced-trigger[href=?]', form_library_path, count: 0
  end
end
