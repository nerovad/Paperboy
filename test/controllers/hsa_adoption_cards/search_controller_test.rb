# frozen_string_literal: true

require 'test_helper'

module HsaAdoptionCards
  class SearchControllerTest < ActionController::TestCase
    tests HsaAdoptionCards::SearchController

    setup do
      # current_user is nil unless the session carries BOTH keys, and a nil
      # current_user fails require_app_access before any app code runs.
      session[:user] = { 'email' => 'searcher@example.com', 'employee_id' => 42, 'first_name' => 'Sam' }
    end

    # Minitest's stub is not available in this suite, so the class method is
    # swapped by hand and always put back.
    def with_card_search(fake)
      original = CardSearch.method(:call)
      CardSearch.define_singleton_method(:call) { |params, app_user:| fake.call(params, app_user: app_user) }
      yield
    ensure
      CardSearch.define_singleton_method(:call, original)
    end

    def grant(*groups)
      names = Set.new(groups)
      @controller.define_singleton_method(:current_user_group_names) { names }
    end

    def grant_features(*keys)
      @controller.define_singleton_method(:current_user_application_permission_keys) { ['hsa_adoption_cards'] }
      @controller.define_singleton_method(:current_user_feature_permission_keys) { keys }
      @controller.define_singleton_method(:current_user_dropdown_permissions) { [] }
      grant('staff')
    end

    test 'a signed-out visitor is sent to the front page' do
      session[:user] = nil
      get :index
      assert_redirected_to root_path
    end

    test 'holding the app without the search feature lands on the app home' do
      grant_features('hsa_adoption_cards:browse')
      get :index
      assert_redirected_to hsa_adoption_cards_root_path
    end

    test 'the search feature opens the page' do
      grant_features('hsa_adoption_cards:search')
      get :index
      assert_response :success
      assert_select '[data-controller=hsa-adoption-cards]'
      assert_select 'input.hsa-ac-box'
      assert_select 'button.btn.approve', text: 'Search'
    end

    test 'a system admin needs no grants' do
      grant('system_admins')
      get :index
      assert_response :success
    end

    test 'a search posts JSON and gets rows back with the signed-in user' do
      grant_features('hsa_adoption_cards:search')
      captured = nil
      fake = lambda do |params, app_user:|
        captured = [params, app_user]
        [{ 'ID' => 1, 'CardType' => 'CHILD' }]
      end

      with_card_search(fake) do
        post :create, body: { lastName: 'Cross', nested: { no: 'way' }, fuzzy: 1 }.to_json, as: :json
      end

      assert_response :success
      body = response.parsed_body
      assert_equal 'searcher@example.com', body['user']
      assert_equal [{ 'ID' => 1, 'CardType' => 'CHILD' }], body['rows']
      assert_equal({ 'lastName' => 'Cross', 'fuzzy' => 1 }, captured.first)
      assert_equal 'searcher@example.com', captured.last
    end

    test 'a refusal from the procedure is returned as an error the page can show' do
      grant_features('hsa_adoption_cards:search')
      refusal = AccessDenied.new('Your account is not authorised.', detail: 'EXECUTE denied')

      with_card_search(->(*) { raise refusal }) do
        post :create, body: { lastName: 'Cross' }.to_json, as: :json
      end

      assert_response :success
      assert_equal({ 'error' => 'Your account is not authorised.', 'detail' => 'EXECUTE denied' }, response.parsed_body)
    end
  end
end
