# frozen_string_literal: true

require 'test_helper'

# Collections in the Form Library: the page each one gets, what the form ACL
# lets a viewer see in it, and finding one from the search box.
class FormLibraryCollectionsTest < ActionController::TestCase
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

  def collection_of(*form_keys, name: 'Human Resources')
    Forms::Collection.create!(name: name, created_by_id: '7', created_by_name: 'Pat Lee').tap do |collection|
      form_keys.each { |key| collection.collection_forms.create!(form_key: key) }
    end
  end

  test 'a collection has a page of its own, listing only its forms' do
    collection = collection_of('42')
    with_templates([bike_locker]) { get :index, params: { collection: collection.id } }

    assert_response :success
    assert_select 'h1', text: 'Human Resources'
    assert_select '.form-library__byline', text: /Created by Pat Lee on/
    assert_select '.form-library__row a', text: 'Bike Locker'
    assert_select '.form-library__row a', text: 'Leave of Absence', count: 0
    assert_select '.sidebar form.form-library-filters[action=?]', form_library_collection_path(collection)
  end

  test 'a collection shows only the forms in it that the viewer may open' do
    collection = collection_of('42', 'leave_of_absence')
    @controller.define_singleton_method(:current_user_group_names) { Set.new }
    @controller.define_singleton_method(:current_user_form_permission_keys) { Set.new(['42']) }
    @controller.define_singleton_method(:current_user_feature_permission_keys) { Set.new }

    with_templates([bike_locker]) { get :index, params: { collection: collection.id } }

    assert_response :success
    assert_select '.form-library__row', count: 1
    assert_select '.form-library__row a', text: 'Bike Locker'
    assert_select '.form-library__manage', count: 0
  end

  test 'a collection holding nothing the viewer may open is a missing page' do
    collection = collection_of('leave_of_absence')
    @controller.define_singleton_method(:current_user_group_names) { Set.new }
    @controller.define_singleton_method(:current_user_form_permission_keys) { Set.new(['42']) }
    @controller.define_singleton_method(:current_user_feature_permission_keys) { Set.new }

    with_templates([bike_locker]) { get :index, params: { collection: collection.id } }

    assert_response :not_found
  end

  test 'someone who may manage collections is offered the controls' do
    collection = collection_of('42')
    with_templates([bike_locker]) { get :index, params: { collection: collection.id } }

    assert_select 'a[href=?]', edit_form_collection_path(collection)
  end

  test 'searching brings up the collections that match beside the forms' do
    collection_of('42')
    collection_of('42', name: 'Fleet')
    with_templates([bike_locker]) { get :index, params: { q: 'human' } }

    assert_select '.form-library__collection', count: 1
    assert_select '.form-library__collection strong', text: 'Human Resources'
  end
end
