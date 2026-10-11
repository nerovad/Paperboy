# frozen_string_literal: true

require 'test_helper'

# Creating and curating Form Library collections — the Paperboy
# `form_collections` feature grant.
class FormCollectionsControllerTest < ActionController::TestCase
  tests FormCollectionsController

  setup do
    session[:user] = {
      'employee_id' => 102_989,
      'email' => 'maria.acosta@example.com',
      'first_name' => 'Maria',
      'last_name' => 'Acosta'
    }
    @controller.define_singleton_method(:current_user_dropdown_permissions) { Set.new }
    @controller.define_singleton_method(:inbox_count) { 0 }
    sign_in_with(features: ['paperboy:form_collections'], forms: %w[leave_of_absence notice_of_change])
  end

  def sign_in_with(features: [], forms: [], groups: [])
    @controller.define_singleton_method(:current_user_group_names) { Set.new(groups) }
    @controller.define_singleton_method(:current_user_feature_permission_keys) { Set.new(features) }
    @controller.define_singleton_method(:current_user_form_permission_keys) { Set.new(forms) }
  end

  def without_templates(&block)
    relation = Object.new
    relation.define_singleton_method(:includes) { |*| [] }

    Forms::Template.stub(:active, relation, &block)
  end

  test 'without the grant nothing here is reachable' do
    sign_in_with(forms: %w[leave_of_absence])

    without_templates { get :new }
    assert_redirected_to form_library_path

    assert_no_difference 'Forms::Collection.count' do
      without_templates { post :create, params: { collection: { name: 'Sneaky' } } }
    end
  end

  test 'new offers only the forms the editor may open' do
    without_templates { get :new }

    assert_response :success
    assert_select 'input[name=?]', 'collection[form_keys][]', count: 2
    assert_select 'input[name=?][value=workplace_violence]', 'collection[form_keys][]', count: 0
  end

  test 'create records who made the collection and the forms chosen' do
    without_templates do
      post :create, params: { collection: { name: 'Human Resources', description: 'Leave and more',
                                            form_keys: %w[leave_of_absence] } }
    end

    collection = Forms::Collection.order(:id).last

    assert_redirected_to form_library_collection_path(collection)
    assert_equal '102989', collection.created_by_id
    assert_equal 'Maria Acosta', collection.created_by_name
    assert_equal %w[leave_of_absence], collection.form_keys
  end

  test 'create cannot add a form the editor may not open' do
    without_templates do
      post :create, params: { collection: { name: 'Reach', form_keys: %w[leave_of_absence workplace_violence] } }
    end

    assert_equal %w[leave_of_absence], Forms::Collection.order(:id).last.form_keys
  end

  test 'create without a name shows the form again' do
    assert_no_difference 'Forms::Collection.count' do
      without_templates { post :create, params: { collection: { name: '' } } }
    end

    assert_response :unprocessable_entity
  end

  test 'update leaves alone a form the editor cannot see' do
    collection = Forms::Collection.create!(name: 'Mixed')
    %w[leave_of_absence workplace_violence].each { |key| collection.collection_forms.create!(form_key: key) }

    without_templates do
      patch :update, params: { id: collection.id,
                               collection: { name: 'Mixed', form_keys: %w[notice_of_change] } }
    end

    assert_equal %w[notice_of_change workplace_violence], collection.reload.form_keys.sort
  end

  test 'destroy removes the collection and its rows' do
    collection = Forms::Collection.create!(name: 'Gone')
    collection.collection_forms.create!(form_key: 'leave_of_absence')

    without_templates { delete :destroy, params: { id: collection.id } }

    assert_redirected_to form_library_path
    assert_not Forms::Collection.exists?(collection.id)
    assert_equal 0, Forms::CollectionForm.where(form_collection_id: collection.id).count
  end
end
